// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- PayPal's events name the order PayPal made, which an intent whose
// provider answer was uncertain does not know yet. The order carries the
// intent's own id (custom_id): an approved order or a completed capture finds
// the intent by it, and its order -- the order event's own id, a capture's
// related order, never a capture's or a refund's id -- is attached once PayPal
// has verified the event. A capture that names no order is retried with
// nothing written; a reversal never attaches; an event PayPal does not verify,
// or naming nothing that waits, writes nothing.
import { assertEquals } from "jsr:@std/assert@1";
import { handle, serve } from "./index.ts";
import { intentsFake } from "../_shared/testing/intents_fake.ts";

const INTENT = "00000000-0000-4000-8000-000000003917";

const waiting = (orderId = "pending:3917") => [{
  id: INTENT,
  provider: "paypal",
  order_id: orderId,
  workspace_id: "ws-1",
  amount_cents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
  status: "created",
}];

const fake = (opts: Partial<Parameters<typeof intentsFake>[0]> = {}) =>
  intentsFake({
    rows: waiting(),
    credentials: {
      client_id: "c",
      secret: "s",
      env: "sandbox",
      webhook_id: "wh",
    },
    ...opts,
  });

const amount = { value: "12.50", currency_code: "EUR" };
const capture = (
  customId: string,
  related: unknown = { order_id: "O-LATE" },
) => ({
  event_type: "PAYMENT.CAPTURE.COMPLETED",
  resource: {
    id: "CAP-1",
    status: "COMPLETED",
    amount,
    custom_id: customId,
    ...(related ? { supplementary_data: { related_ids: related } } : {}),
  },
});
const approved = () => ({
  event_type: "CHECKOUT.ORDER.APPROVED",
  resource: {
    id: "O-LATE",
    status: "APPROVED",
    purchase_units: [{ custom_id: INTENT, amount }],
  },
});
const refunded = () => ({
  event_type: "PAYMENT.CAPTURE.REFUNDED",
  resource: { id: "REF-1", status: "COMPLETED", amount, custom_id: INTENT },
});

async function call(
  f: ReturnType<typeof intentsFake>,
  event: unknown,
  verified = "SUCCESS",
) {
  const asked: string[] = [];
  const req = new Request("http://x/paypal-webhook", {
    method: "POST",
    body: JSON.stringify(event),
  });
  const res = await handle(req, {
    admin: () => f.admin,
    env: () => undefined,
    fetch: (input) => {
      const url = String(input);
      asked.push(url);
      if (url.endsWith("/v1/oauth2/token")) {
        return Promise.resolve(Response.json({ access_token: "t" }));
      }
      if (url.endsWith("/verify-webhook-signature")) {
        return Promise.resolve(
          Response.json({ verification_status: verified }),
        );
      }
      if (url.endsWith("/capture")) {
        return Promise.resolve(Response.json({
          id: "O-LATE",
          status: "COMPLETED",
          purchase_units: [{
            payments: {
              captures: [{ id: "CAP-1", status: "COMPLETED", amount }],
            },
          }],
        }));
      }
      return Promise.resolve(new Response("", { status: 404 }));
    },
    allowTest: () => true,
  });
  return { status: res.status, asked };
}

const settled = (f: ReturnType<typeof intentsFake>) =>
  f.rpcCalls.filter((c) => c.name === "settle_online_payment").map((
    c,
  ) => [c.args.p_provider, c.args.p_order_id]);

Deno.test("a capture naming an intent that waits attaches its related order and settles on it", async () => {
  const f = fake();
  assertEquals((await call(f, capture(INTENT))).status, 200);
  assertEquals(f.rows[0].order_id, "O-LATE");
  assertEquals(settled(f), [["paypal", "O-LATE"]]);
});

Deno.test("an approved order on the provisional path attaches its own id and captures that order", async () => {
  const f = fake();
  const { status, asked } = await call(f, approved());
  assertEquals(status, 200);
  assertEquals(f.rows[0].order_id, "O-LATE");
  assertEquals(
    asked.filter((u) => u.endsWith("/capture")).map((u) => u.split("/").at(-2)),
    ["O-LATE"],
  );
  assertEquals(settled(f), [["paypal", "O-LATE"]]);
});

Deno.test("a capture that names no order attaches nothing and is retried", async () => {
  const f = fake();
  assertEquals((await call(f, capture(INTENT, null))).status, 500);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a refund-shaped event without its up link never attaches", async () => {
  const f = fake();
  assertEquals((await call(f, refunded())).status, 200);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("the order request's late write before the attach: no row changed, settled on the stored order", async () => {
  const f = fake({
    afterRead: (rows) => (rows[0].order_id = "O-LATE"),
    afterReadAt: 2,
  });
  assertEquals((await call(f, capture(INTENT))).status, 200);
  assertEquals(settled(f), [["paypal", "O-LATE"]]);
});

Deno.test("a redelivery after the attach takes the known-order path", async () => {
  const f = fake();
  await call(f, capture(INTENT));
  assertEquals((await call(f, capture(INTENT))).status, 200);
  assertEquals(
    settled(f),
    [["paypal", "O-LATE"], ["paypal", "O-LATE"]],
    "the database credits it once",
  );
});

Deno.test("a custom id naming nothing that waits settles nothing and answers 200", async () => {
  const f = fake({ rows: waiting("O-OTHER") });
  assertEquals((await call(f, capture(INTENT))).status, 200);
  assertEquals(f.rows[0].order_id, "O-OTHER");
  assertEquals(f.rpcCalls, []);
});

Deno.test("an event PayPal does not verify attaches and settles nothing", async () => {
  const f = fake();
  assertEquals((await call(f, capture(INTENT), "FAILURE")).status, 400);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("an order made before this change (its custom id is the reference) names no intent", async () => {
  const f = fake();
  assertEquals((await call(f, capture("PAY-2026-0001"))).status, 200);
  assertEquals(f.rows[0].order_id, "pending:3917");
  assertEquals(f.rpcCalls, []);
});

Deno.test("a failed read of the intents is a 500, nothing written", async () => {
  const f = fake({ readError: true });
  assertEquals((await call(f, capture(INTENT))).status, 500);
  assertEquals(f.rpcCalls, []);
});

Deno.test("#4126: a settlement that throws after the capture is answered 500, as before", async () => {
  const f = fake();
  f.admin.rpc = () => Promise.reject(new Error("connection lost"));
  assertEquals((await call(f, approved())).status, 500);
});

// #4412 -- an uncaught error is the envelope: a code and the request id, never the error's own words.
Deno.test("#4412 paypal-webhook: a thrown error answers the envelope and no internal message", async () => {
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
    })(new Request("https://x.test/paypal-webhook", {
      method: "POST",
      headers: { "x-request-id": "r-hook" },
      body: JSON.stringify({ event_type: "CHECKOUT.ORDER.APPROVED", resource: { id: "ORDER1" } }),
    }));
    assertEquals(answer.status, 500);
    const text = await answer.text();
    assertEquals(JSON.parse(text), { error: "internal_error", request_id: "r-hook" });
    assertEquals(/secret|sb_|wrong/i.test(text), false);
  } finally {
    console.error = saved;
  }
});
