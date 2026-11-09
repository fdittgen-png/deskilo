// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 -- a Stripe payout is recorded with the payments it carried, by the
// workspace whose own webhook secret signed it; refusals and recovery.
import { assertEquals } from "jsr:@std/assert@1";
import { handlePayout, isPayoutEvent } from "./payout.ts";

const SECRET = "whsec_ws1";

type Result = { data: unknown; error: { message: string } | null };

function fakeAdmin(opts: {
  credentials?: Result;
  rpc?: Result;
}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const admin = {
    from() {
      const chain = {
        select: () => chain,
        eq: () =>
          Promise.resolve(
            opts.credentials ?? {
              data: [
                { workspace_id: "ws-other", config: { webhook_secret: "whsec_other", secret_key: "sk_other" } },
                { workspace_id: "ws-1", config: { webhook_secret: SECRET, secret_key: "sk_test_1" } },
              ],
              error: null,
            },
          ),
      };
      return chain;
    },
    rpc(name: string, args: Record<string, unknown>) {
      calls.push({ name, args });
      return Promise.resolve(opts.rpc ?? { data: { reconciled: true, payments: 3, net_cents: 34866 }, error: null });
    },
  };
  return { admin, calls };
}

const payoutEvent = (type = "payout.paid", over: Record<string, unknown> = {}) => ({
  type,
  data: {
    object: {
      id: "po_1", object: "payout", amount: 34866, currency: "eur", status: "paid",
      arrival_date: 1773532800, // 2026-03-15
      ...over,
    },
  },
});

const page = (ids: string[], hasMore = false, types: Record<string, string> = {}) =>
  new Response(JSON.stringify({
    data: ids.map((id) => ({ id, type: types[id] ?? "charge" })),
    has_more: hasMore,
  }), { status: 200 });

const run = (
  fake: ReturnType<typeof fakeAdmin>,
  event: Record<string, unknown>,
  fetchFn: typeof fetch,
  secret = SECRET,
) =>
  handlePayout(
    event,
    (s) => Promise.resolve(s === secret),
    // deno-lint-ignore no-explicit-any
    { admin: () => fake.admin as any, env: () => undefined, fetch: fetchFn },
  );

Deno.test("the payout event types the books record", () => {
  for (const t of ["payout.paid", "payout.failed", "payout.canceled"]) assertEquals(isPayoutEvent(t), true);
  for (const t of ["payout.created", "payout.updated", "charge.succeeded", undefined]) assertEquals(isPayoutEvent(t), false);
});

Deno.test("a paid payout records its amount, arrival and the payments it carried, for the workspace that signed it", async () => {
  const fake = fakeAdmin({});
  const urls: string[] = [];
  const keys: string[] = [];
  const res = await run(fake, payoutEvent(), (input, init) => {
    urls.push(String(input));
    keys.push(String((init?.headers as Record<string, string>).Authorization));
    return Promise.resolve(page(["txn_1", "txn_2", "txn_3", "txn_po"], false, { txn_po: "payout" }));
  });
  assertEquals(res.status, 200);
  assertEquals(urls, ["https://api.stripe.com/v1/balance_transactions?payout=po_1&limit=100"]);
  assertEquals(keys, ["Bearer sk_test_1"]);
  assertEquals(fake.calls.length, 1);
  assertEquals(fake.calls[0].name, "record_provider_payout_v1");
  assertEquals(fake.calls[0].args, {
    p_workspace_id: "ws-1", p_provider: "stripe", p_payout_id: "po_1", p_amount_cents: 34866,
    p_currency: "EUR", p_arrival_date: "2026-03-15", p_status: "paid",
    p_transaction_ids: ["txn_1", "txn_2", "txn_3"],
  });
});

Deno.test("a payout of more than one page of payments is read to its end", async () => {
  const fake = fakeAdmin({});
  const urls: string[] = [];
  const res = await run(fake, payoutEvent(), (input) => {
    urls.push(String(input));
    return Promise.resolve(urls.length === 1 ? page(["txn_1", "txn_2"], true) : page(["txn_3"]));
  });
  assertEquals(res.status, 200);
  assertEquals(urls[1], "https://api.stripe.com/v1/balance_transactions?payout=po_1&limit=100&starting_after=txn_2");
  assertEquals((fake.calls[0].args.p_transaction_ids as string[]), ["txn_1", "txn_2", "txn_3"]);
});

Deno.test("an event no workspace's own secret signed records nothing and is acknowledged", async () => {
  const fake = fakeAdmin({});
  let called = false;
  const res = await run(fake, payoutEvent(), () => { called = true; return Promise.resolve(page([])); }, "whsec_installation");
  assertEquals(res.status, 200);
  assertEquals(called, false);
  assertEquals(fake.calls, []);
});

Deno.test("a failed payout is recorded as failed without reading its payments", async () => {
  const fake = fakeAdmin({});
  let called = false;
  const res = await run(fake, payoutEvent("payout.failed", { status: "failed" }), () => { called = true; return Promise.resolve(page([])); });
  assertEquals(res.status, 200);
  assertEquals(called, false);
  assertEquals(fake.calls[0].args.p_status, "failed");
  assertEquals(fake.calls[0].args.p_transaction_ids, []);
});

for (const status of [403, 404]) {
  Deno.test(`a ${status} on the payout read (a key Stripe refuses) is logged and answered 2xx, nothing recorded`, async () => {
    const fake = fakeAdmin({});
    const res = await run(fake, payoutEvent(), () => Promise.resolve(new Response("{}", { status })));
    assertEquals(res.status, 200);
    assertEquals(fake.calls, []);
  });
}

Deno.test("a 503 or a network failure on the payout read is a 500: Stripe redelivers", async () => {
  const a = await run(fakeAdmin({}), payoutEvent(), () => Promise.resolve(new Response("{}", { status: 503 })));
  assertEquals(a.status, 500);
  const b = await run(fakeAdmin({}), payoutEvent(), () => Promise.reject(new Error("socket")));
  assertEquals(b.status, 500);
  assertEquals(await b.text(), "payout_read_failed");
});

Deno.test("a payout the database refuses (another amount) is a 500, never an ok", async () => {
  const fake = fakeAdmin({ rpc: { data: null, error: { message: "the provider reported this payout with another amount" } } });
  const res = await run(fake, payoutEvent(), () => Promise.resolve(page(["txn_1"])));
  assertEquals(res.status, 500);
  assertEquals(await res.text(), "payout_record_failed");
});

Deno.test("a credential lookup failure is a 500 and a payout with no key or no amount is ignored", async () => {
  const down = await run(fakeAdmin({ credentials: { data: null, error: { message: "down" } } }), payoutEvent(), () => Promise.resolve(page([])));
  assertEquals(down.status, 500);
  const noKey = fakeAdmin({
    credentials: { data: [{ workspace_id: "ws-1", config: { webhook_secret: SECRET } }], error: null },
  });
  assertEquals((await run(noKey, payoutEvent(), () => Promise.resolve(page([])))).status, 200);
  assertEquals(noKey.calls, []);
  const malformed = fakeAdmin({});
  assertEquals((await run(malformed, payoutEvent("payout.paid", { amount: "x" }), () => Promise.resolve(page([])))).status, 200);
  assertEquals(malformed.calls, []);
});

Deno.test("two workspaces sharing one Stripe secret: the payout is attributed to neither", async () => {
  const fake = fakeAdmin({
    credentials: {
      data: [
        { workspace_id: "ws-prod", config: { webhook_secret: SECRET, secret_key: "sk_a" } },
        { workspace_id: "ws-twin", config: { webhook_secret: SECRET, secret_key: "sk_a" } },
      ],
      error: null,
    },
  });
  let called = false;
  const res = await run(fake, payoutEvent(), () => { called = true; return Promise.resolve(page(["txn_1"])); });
  assertEquals(res.status, 200);
  assertEquals(called, false);
  assertEquals(fake.calls, []);
});
