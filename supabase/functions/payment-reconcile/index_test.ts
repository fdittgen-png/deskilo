// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4126 -- a reconciliation run: only the database job's secret or the
// service credential starts it, never a delegated token; the run's start is
// the database's; it reads each claimed attempt with its provider, settles
// once what is paid, ends what the provider ended (counted only when this
// write ended it), leaves what is pending, ends an attempt never given an
// order, names what it cannot read or write, stops at its budget and records
// what it has with the lease.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, RECONCILE_SECRET_HEADER, RUN_BUDGET_MS, serve } from "./index.ts";

const WS = "00000000-0000-4000-8000-00000000a126";
const SECRET = "reconcile-secret";
const SERVICE = "service-credential";

type Call = { fn: string; args: Record<string, unknown> };

function fakeService(opts: {
  claims: unknown[];
  status?: Record<string, string>;
  rpcErrors?: Record<string, string>;
  finishKept?: boolean;
}) {
  const calls: Call[] = [];
  const service = {
    rpc(
      fn: string,
      args: Record<string, unknown>,
    ): Promise<{ data: unknown; error: unknown }> {
      calls.push({ fn, args });
      const message = opts.rpcErrors?.[fn];
      if (message) return Promise.resolve({ data: null, error: { message } });
      if (fn === "payment_reconciliation_begin_v1") {
        return Promise.resolve({
          data: "2026-11-16T10:00:00+00:00",
          error: null,
        });
      }
      if (fn === "payment_reconciliation_claim_v1") {
        return Promise.resolve({
          data: opts.claims.length ? [opts.claims.shift()] : [],
          error: null,
        });
      }
      if (fn === "payment_reconciliation_finish_v1") {
        return Promise.resolve({ data: opts.finishKept ?? true, error: null });
      }
      return Promise.resolve({ data: null, error: null });
    },
    from(table: string) {
      let id = "";
      const chain = {
        select: () => chain,
        eq: (c: string, v: string) => {
          if (c === "id") id = v;
          return chain;
        },
        maybeSingle: () =>
          Promise.resolve(
            table === "payment_intents"
              ? { data: { status: opts.status?.[id] ?? "failed" }, error: null }
              : { data: { config: { secret_key: "sk_live_x" } }, error: null },
          ),
      };
      return chain;
    },
  };
  return { service, calls };
}

const open = (id: string, orderId: string) => ({
  id,
  provider: "stripe",
  order_id: orderId,
  amount_cents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
});

/** Stripe's answers: a session per id, and its payment intent. */
function stripe(
  sessions: Record<string, Response | Error>,
  intents: Record<string, Response> = {},
) {
  return (input: string | URL | Request) => {
    const url = new URL(String(input));
    const id = decodeURIComponent(url.pathname.split("/").pop() ?? "");
    const a = url.pathname.includes("/payment_intents/")
      ? intents[id] ??
        Response.json({
          id,
          status: "succeeded",
          latest_charge: {
            refunded: false,
            amount_refunded: 0,
            disputed: false,
          },
        })
      : sessions[id] ?? new Response("", { status: 500 });
    return a instanceof Error ? Promise.reject(a) : Promise.resolve(a.clone());
  };
}

const session = (id: string, over: Record<string, unknown>) =>
  Response.json({
    id,
    livemode: true,
    status: "complete",
    payment_status: "paid",
    amount_total: 1250,
    currency: "eur",
    payment_intent: `pi_${id}`,
    ...over,
  });

async function run(
  fake: ReturnType<typeof fakeService>,
  fetchFn: unknown,
  headers: Record<string, string>,
  clock: () => number = (() => {
    let t = 1_800_000_000_000;
    return () => (t += 10);
  })(),
) {
  const res = await handle(
    new Request("http://x/payment-reconcile", { method: "POST", headers }),
    {
      // deno-lint-ignore no-explicit-any
      service: () => fake.service as any,
      env: (n) =>
        n === "PAYMENT_RECONCILE_SECRET"
          ? SECRET
          : n === "SUPABASE_SERVICE_ROLE_KEY"
          ? SERVICE
          : n === "STRIPE_API_BASE"
          ? "http://stripe"
          : undefined,
      fetch: fetchFn as typeof fetch,
      now: clock,
    },
  );
  return { status: res.status, body: await res.json() };
}

const job = { [RECONCILE_SECRET_HEADER]: SECRET };
const finishOf = (fake: ReturnType<typeof fakeService>) =>
  fake.calls.find((c) => c.fn === "payment_reconciliation_finish_v1")?.args
    .p_result as Record<string, unknown>;

Deno.test("only the database job's secret or the service credential starts a run, never a delegated token", async () => {
  const fake = fakeService({ claims: [] });
  assertEquals((await run(fake, stripe({}), {})).status, 401);
  assertEquals(
    (await run(fake, stripe({}), { [RECONCILE_SECRET_HEADER]: "guess" }))
      .status,
    401,
  );
  const delegated = `x.${btoa(JSON.stringify({ client_id: "assistant" }))}.y`;
  assertEquals(
    (await run(fake, stripe({}), { Authorization: `Bearer ${delegated}` }))
      .status,
    403,
  );
  assertEquals(fake.calls, [], "nothing is begun or claimed");
  assertEquals(
    (await run(fake, stripe({}), { Authorization: `Bearer ${SERVICE}` }))
      .status,
    200,
  );
});

Deno.test("the run's marker is the database's start", async () => {
  const fake = fakeService({ claims: [] });
  await run(fake, stripe({}), job);
  assertEquals(fake.calls.map((c) => c.fn), [
    "payment_reconciliation_begin_v1",
    "payment_reconciliation_claim_v1",
  ]);
  assertEquals(fake.calls[1].args.p_run_started, "2026-11-16T10:00:00+00:00");
});

Deno.test("a run settles once what is paid, ends what expired, leaves what is pending, names what it cannot read, ends what never had an order", async () => {
  const fake = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [
        open("i-paid", "cs_paid"),
        open("i-expired", "cs_expired"),
        open("i-open", "cs_open"),
        open("i-down", "cs_down"),
        open("i-uncertain", "pending:uncertain"),
      ],
    }],
  });
  const { status } = await run(
    fake,
    stripe({
      cs_paid: session("cs_paid", {}),
      cs_expired: session("cs_expired", {
        status: "expired",
        payment_status: "unpaid",
      }),
      cs_open: session("cs_open", { status: "open", payment_status: "unpaid" }),
      cs_down: new TypeError("connection reset"),
    }),
    job,
  );
  assertEquals(status, 200);
  assertEquals(
    fake.calls.filter((c) =>
      c.fn === "settle_online_payment" || c.fn === "mark_payment_failed"
    )
      .map((c) => [c.fn, c.args.p_order_id]),
    [
      ["settle_online_payment", "cs_paid"],
      ["mark_payment_failed", "cs_expired"],
      ["mark_payment_failed", "pending:uncertain"],
    ],
  );
  const result = finishOf(fake);
  assertEquals([
    result.read,
    result.settled,
    result.ended,
    result.left,
    result.abandoned,
  ], [4, 1, 1, 1, 1]);
  assertEquals(result.unreadable, [{
    intent: "i-down",
    reason: "unreachable",
  }]);
});

Deno.test("an end is counted only when this write ended it: settled meanwhile is left, unchanged is named", async () => {
  const fake = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [
        open("i-raced", "cs_raced"),
        open("i-stuck", "cs_stuck"),
        open("i-gone", "pending:gone"),
      ],
    }],
    status: {
      "i-raced": "captured",
      "i-stuck": "created",
      "i-gone": "created",
    },
  });
  await run(
    fake,
    stripe({
      cs_raced: session("cs_raced", {
        status: "expired",
        payment_status: "unpaid",
      }),
      cs_stuck: session("cs_stuck", {
        status: "expired",
        payment_status: "unpaid",
      }),
    }),
    job,
  );
  const result = finishOf(fake);
  assertEquals([result.ended, result.left, result.abandoned], [0, 1, 0]);
  assertEquals(result.unreadable, [
    { intent: "i-stuck", reason: "record_failed" },
    { intent: "i-gone", reason: "record_failed" },
  ]);
});

Deno.test("a failed settlement or end write leaves the attempt and names it", async () => {
  const fake = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [open("i-paid", "cs_paid"), open("i-expired", "cs_expired")],
    }],
    rpcErrors: { settle_online_payment: "down", mark_payment_failed: "down" },
  });
  await run(
    fake,
    stripe({
      cs_paid: session("cs_paid", {}),
      cs_expired: session("cs_expired", { status: "expired" }),
    }),
    job,
  );
  const result = finishOf(fake);
  assertEquals([result.settled, result.ended], [0, 0]);
  assertEquals(result.unreadable, [
    { intent: "i-paid", reason: "record_failed" },
    { intent: "i-expired", reason: "record_failed" },
  ]);
});

Deno.test("a run stops at its budget, per attempt, and records what it has", async () => {
  const fake = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [open("i-1", "cs_1"), open("i-2", "cs_2"), open("i-3", "cs_3")],
    }],
  });
  const t = 1_800_000_000_000;
  let reads = 0;
  // The clock stands still until the first attempt is read, then jumps past the budget.
  const clock = () => (reads++ < 3 ? t : t + RUN_BUDGET_MS);
  await run(
    fake,
    stripe({
      cs_1: session("cs_1", {}),
      cs_2: session("cs_2", {}),
      cs_3: session("cs_3", {}),
    }),
    job,
    clock,
  );
  const result = finishOf(fake);
  assertEquals(
    result.read,
    1,
    "the remaining attempts are claimed again later",
  );
  assertEquals(
    result.read_items,
    [{ intent: "i-1" }],
    "only the attempt read is stamped: the others keep their place",
  );
  assertEquals(
    fake.calls.filter((c) => c.fn === "settle_online_payment").length,
    1,
  );
});

Deno.test("a failed begin or claim is a 500, nothing read; a finish that kept nothing says so", async () => {
  const noBegin = fakeService({
    claims: [],
    rpcErrors: { payment_reconciliation_begin_v1: "down" },
  });
  assertEquals((await run(noBegin, stripe({}), job)).status, 500);
  const noClaim = fakeService({
    claims: [],
    rpcErrors: { payment_reconciliation_claim_v1: "down" },
  });
  assertEquals((await run(noClaim, stripe({}), job)).status, 500);
  const notKept = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [open("i-open", "cs_open")],
    }],
    finishKept: false,
  });
  const { body } = await run(
    notKept,
    stripe({ cs_open: session("cs_open", { status: "open" }) }),
    job,
  );
  assertEquals(body.runs[0].kept, false);
});

Deno.test("a settlement records what the provider kept, once, as the notification would; a failed record is named", async () => {
  const fee = (id: string) =>
    Response.json({
      id,
      status: "succeeded",
      latest_charge: {
        refunded: false,
        amount_refunded: 0,
        disputed: false,
        balance_transaction: {
          id: "txn_1",
          currency: "eur",
          fee: 41,
          net: 1209,
        },
      },
    });
  const fake = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [open("i-paid", "cs_paid")],
    }],
  });
  await run(
    fake,
    stripe({ cs_paid: session("cs_paid", {}) }, {
      pi_cs_paid: fee("pi_cs_paid"),
    }),
    job,
  );
  assertEquals(
    fake.calls.filter((c) => c.fn === "record_provider_fee_v1").map((c) =>
      c.args
    ),
    [{
      p_provider: "stripe",
      p_order_id: "cs_paid",
      p_fee_cents: 41,
      p_net_cents: 1209,
      p_currency: "EUR",
      p_transaction_id: "txn_1",
    }],
  );
  const failed = fakeService({
    claims: [{
      workspace_id: WS,
      lease_token: "lease-1",
      intents: [open("i-paid", "cs_paid")],
    }],
    rpcErrors: { record_provider_fee_v1: "down" },
  });
  await run(
    failed,
    stripe({ cs_paid: session("cs_paid", {}) }, {
      pi_cs_paid: fee("pi_cs_paid"),
    }),
    job,
  );
  const result = finishOf(failed);
  assertEquals(result.settled, 1);
  assertEquals(result.unreadable, [{
    intent: "i-paid",
    reason: "record_failed",
  }]);
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
Deno.test("#4412 payment-reconcile: a thrown error answers the envelope and no internal message", async () => {
  const saved = console.error;
  console.error = () => {};
  try {
    const answer = await serve({
      service: () => {
        throw new Error("service role key sb_secret_xyz is wrong");
      },
      env: (n) => (n === "PAYMENT_RECONCILE_SECRET" ? SECRET : n === "SUPABASE_SERVICE_ROLE_KEY" ? SERVICE : undefined),
      fetch: () => Promise.reject(new Error("unused")),
      now: () => Date.now(),
    })(
      new Request("http://x/payment-reconcile", {
        method: "POST",
        headers: { [RECONCILE_SECRET_HEADER]: SECRET, "x-request-id": "r-rec" },
      }),
    );
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-rec" });
    assertEquals(/secret|sb_|wrong/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
