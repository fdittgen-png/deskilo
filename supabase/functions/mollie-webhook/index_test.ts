// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- Mollie posts only a payment id. An intent whose provider answer
// was uncertain does not know it yet, so the webhook address names the
// intent; the payment is attached and settled on it only when Mollie, asked
// with the business's own key, shows that the payment carries that intent.
// The order request's own late write wins; a redelivery takes the
// known-payment path; an address naming nothing waiting, a payment carrying
// another intent, an unreachable Mollie or a failed read attaches nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, serve } from "./index.ts";
import { intentsFake } from "../_shared/testing/intents_fake.ts";

const INTENT = "00000000-0000-4000-8000-000000003917";
const KEY = "live_businesskey";

const waiting = (orderId = "pending:3917") => [{
  id: INTENT,
  provider: "mollie",
  order_id: orderId,
  workspace_id: "ws-1",
  amount_cents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
  status: "created",
}];

const fake = (opts: Partial<Parameters<typeof intentsFake>[0]> = {}) =>
  intentsFake({ rows: waiting(), credentials: { api_key: KEY }, ...opts });

const payment = (metadata: Record<string, unknown>) => ({
  id: "tr_late",
  status: "paid",
  mode: "live",
  amount: { value: "12.50", currency: "EUR" },
  metadata,
});
const carrying = () =>
  Promise.resolve(
    Response.json(
      payment({ reference: "PAY-2026-0001", deskilo_intent: INTENT }),
    ),
  );

async function call(
  f: ReturnType<typeof intentsFake>,
  query: string,
  answer: () => Promise<Response> = carrying,
) {
  const asked: Array<{ url: string; auth: string | null }> = [];
  const req = new Request(`http://x/mollie-webhook${query}`, {
    method: "POST",
    body: new URLSearchParams({ id: "tr_late" }),
    headers: { "content-type": "application/x-www-form-urlencoded" },
  });
  const res = await handle(req, {
    admin: () => f.admin,
    env: () => undefined,
    fetch: (input, init) => {
      asked.push({
        url: String(input),
        auth: new Headers(init?.headers).get("Authorization"),
      });
      return answer();
    },
    allowTest: () => false,
  });
  return { status: res.status, asked };
}

const settled = (f: ReturnType<typeof intentsFake>) =>
  f.rpcCalls.filter((c) => c.name === "settle_online_payment").map((
    c,
  ) => [c.args.p_provider, c.args.p_order_id]);

Deno.test("a payment whose intent waits for it: Mollie asked with the business's key, attached and settled on it", async () => {
  const f = fake();
  const { status, asked } = await call(f, `?intent=${INTENT}`);
  assertEquals(status, 200);
  assertEquals(asked, [{
    url: "https://api.mollie.com/v2/payments/tr_late",
    auth: `Bearer ${KEY}`,
  }]);
  assertEquals(f.rows[0].order_id, "tr_late");
  assertEquals(settled(f), [["mollie", "tr_late"]]);
});

Deno.test("the order request's late write before the attach: no row changed, settled on the stored payment", async () => {
  const f = fake({
    afterRead: (rows) => (rows[0].order_id = "tr_late"),
    afterReadAt: 2,
  });
  assertEquals((await call(f, `?intent=${INTENT}`)).status, 200);
  assertEquals(settled(f), [["mollie", "tr_late"]]);
});

Deno.test("a redelivery after the attach takes the known-payment path", async () => {
  const f = fake();
  await call(f, `?intent=${INTENT}`);
  assertEquals((await call(f, `?intent=${INTENT}`)).status, 200);
  assertEquals(
    settled(f),
    [["mollie", "tr_late"], ["mollie", "tr_late"]],
    "the database credits it once",
  );
});

Deno.test("an address naming nothing that waits settles nothing and answers 200", async () => {
  const f = fake({ rows: waiting("tr_other") });
  const { status, asked } = await call(f, `?intent=${INTENT}`);
  assertEquals(status, 200);
  assertEquals(asked, []);
  assertEquals(f.rows[0].order_id, "tr_other");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a payment that does not carry the named intent attaches and settles nothing", async () => {
  const f = fake();
  const { status } = await call(
    f,
    `?intent=${INTENT}`,
    () =>
      Promise.resolve(Response.json(payment({ reference: "PAY-2026-0001" }))),
  );
  assertEquals(status, 200);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("an unreachable Mollie changes nothing and is retried", async () => {
  const f = fake();
  const { status } = await call(
    f,
    `?intent=${INTENT}`,
    () => Promise.reject(new TypeError("connection reset")),
  );
  assertEquals(status, 500);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a failed read of the intents is a 500, nothing written", async () => {
  const f = fake({ readError: true });
  assertEquals((await call(f, `?intent=${INTENT}`)).status, 500);
  assertEquals(f.rpcCalls, []);
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
Deno.test("#4412 mollie-webhook: a thrown error answers the envelope and no internal message", async () => {
  const saved = console.error;
  console.error = () => {};
  try {
    const answer = await serve({
      admin: () => {
        throw new Error("service role key sb_secret_xyz is wrong");
      },
      env: () => undefined,
      fetch: () => Promise.reject(new Error("unused")),
      allowTest: () => false,
    })(new Request("https://x.test/mollie-webhook", {
      method: "POST",
      headers: { "x-request-id": "r-hook", "content-type": "application/x-www-form-urlencoded" },
      body: "id=tr_abc123",
    }));
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-hook" });
    assertEquals(/secret|sb_|wrong/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
