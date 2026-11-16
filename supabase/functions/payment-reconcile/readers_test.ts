// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4126 -- what each provider's answer about an order left open decides:
// settle (once, through settle_online_payment), end, leave while it is still
// pending, or name it unreadable with a reason word and leave it as it is.
import { assertEquals } from "jsr:@std/assert@1";
import {
  clientFingerprint,
  type OpenIntent,
  readMollie,
  readPaypal,
  readStripe,
} from "./readers.ts";

const intent = (
  provider: string,
  orderId: string,
  over: Partial<OpenIntent> = {},
): OpenIntent => ({
  id: "00000000-0000-4000-8000-000000004126",
  provider,
  order_id: orderId,
  amount_cents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
  ...over,
});

/** A fetch answering by the path asked; an Error is a lost connection. */
function provider(
  answers: Record<string, Response | Error | Array<Response | Error>>,
) {
  const seen: string[] = [];
  const headers: Array<Record<string, string>> = [];
  const fetchFn = (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    seen.push(url);
    headers.push(Object.fromEntries(new Headers(init?.headers).entries()));
    const key = Object.keys(answers).find((k) => url.includes(k));
    // An array answers in turn: the same URL read twice.
    const found = key ? answers[key] : new Response("", { status: 500 });
    const a = Array.isArray(found)
      ? (found.length > 1 ? found.shift()! : found[0])
      : found;
    return a instanceof Error
      ? Promise.reject(a)
      : Promise.resolve((a as Response).clone());
  };
  return {
    seen,
    headers,
    deps: (allowTest = false) => ({
      fetch: fetchFn as typeof fetch,
      env: (
        n: string,
      ) => (n === "STRIPE_API_BASE" ? "http://stripe" : undefined),
      allowTest,
      timeoutMs: 1000,
    }),
  };
}

// ── Stripe ──────────────────────────────────────────────────────────────
const stripeCfg = { secret_key: "sk_live_x" };
const session = (over: Record<string, unknown>) =>
  Response.json({
    id: "cs_1",
    livemode: true,
    status: "complete",
    payment_status: "paid",
    amount_total: 1250,
    currency: "eur",
    payment_intent: "pi_1",
    ...over,
  });
const pi = (over: Record<string, unknown>) =>
  Response.json({
    id: "pi_1",
    status: "succeeded",
    latest_charge: { refunded: false, amount_refunded: 0, disputed: false },
    ...over,
  });
const stripeRead = (
  s: Response | Error,
  p: Response | Error = pi({}),
  allowTest = false,
) =>
  readStripe(
    intent("stripe", "cs_1"),
    stripeCfg,
    provider({ "/checkout/sessions/": s, "/payment_intents/": p }).deps(
      allowTest,
    ),
  );

Deno.test("Stripe: a paid session settles on its payment intent; an expired one ends; an open one is left", async () => {
  assertEquals(await stripeRead(session({})), {
    kind: "settle",
    captureId: "pi_1",
    fee: null,
  });
  assertEquals(
    await stripeRead(session({ status: "expired", payment_status: "unpaid" })),
    { kind: "end" },
  );
  assertEquals(
    await stripeRead(session({ status: "open", payment_status: "unpaid" })),
    { kind: "left" },
  );
});

Deno.test("Stripe: a delayed payment that failed ends; one still on its way is left", async () => {
  const unpaid = () => session({ payment_status: "unpaid" });
  assertEquals(await stripeRead(unpaid(), pi({ status: "canceled" })), {
    kind: "end",
  });
  assertEquals(
    await stripeRead(unpaid(), pi({ status: "requires_payment_method" })),
    { kind: "end" },
  );
  assertEquals(await stripeRead(unpaid(), pi({ status: "processing" })), {
    kind: "left",
  });
});

Deno.test("Stripe: a paid session already refunded or disputed is named, never settled as a payment", async () => {
  const refunded = pi({
    latest_charge: { refunded: false, amount_refunded: 500, disputed: false },
  });
  const disputed = pi({
    latest_charge: { refunded: false, amount_refunded: 0, disputed: true },
  });
  assertEquals(await stripeRead(session({}), refunded), {
    kind: "unreadable",
    reason: "unexpected_answer",
  });
  assertEquals(await stripeRead(session({}), disputed), {
    kind: "unreadable",
    reason: "unexpected_answer",
  });
});

Deno.test("Stripe: what does not match or cannot be read is named and left", async () => {
  assertEquals(await stripeRead(session({ amount_total: 999 })), {
    kind: "unreadable",
    reason: "mismatch",
  });
  assertEquals(await stripeRead(session({ currency: "chf" })), {
    kind: "unreadable",
    reason: "mismatch",
  });
  assertEquals(await stripeRead(session({ id: "cs_other" })), {
    kind: "unreadable",
    reason: "unexpected_answer",
  });
  assertEquals(await stripeRead(new Response("", { status: 404 })), {
    kind: "unreadable",
    reason: "unknown_order",
  });
  assertEquals(await stripeRead(new Response("", { status: 503 })), {
    kind: "unreadable",
    reason: "unreachable",
  });
  assertEquals(await stripeRead(new TypeError("reset")), {
    kind: "unreadable",
    reason: "unreachable",
  });
  assertEquals(await stripeRead(new Response("", { status: 401 })), {
    kind: "unreadable",
    reason: "refused",
  });
  assertEquals(
    await stripeRead(session({}), new Response("", { status: 503 })),
    { kind: "unreadable", reason: "unreachable" },
  );
  assertEquals(
    await readStripe(intent("stripe", "cs_1"), {}, provider({}).deps()),
    { kind: "unreadable", reason: "not_configured" },
  );
});

Deno.test("Stripe: a test session settles nothing where the installation takes no test payments", async () => {
  assertEquals(await stripeRead(session({ livemode: false })), {
    kind: "left",
  });
});

// ── Mollie ──────────────────────────────────────────────────────────────
const molliePayment = (over: Record<string, unknown>) =>
  Response.json({
    id: "tr_1",
    status: "paid",
    mode: "live",
    amount: { value: "12.50", currency: "EUR" },
    metadata: { reference: "PAY-2026-0001" },
    ...over,
  });
const mollieRead = (a: Response | Error, key = "live_x", allowTest = false) =>
  readMollie(
    intent("mollie", "tr_1"),
    { api_key: key },
    provider({ "/v2/payments/": a }).deps(allowTest),
  );

Deno.test("Mollie: a paid payment settles, a failed, canceled or expired one ends, an open one is left", async () => {
  assertEquals(await mollieRead(molliePayment({})), {
    kind: "settle",
    captureId: "tr_1",
  });
  for (const status of ["failed", "canceled", "expired"]) {
    assertEquals(
      await mollieRead(molliePayment({ status })),
      { kind: "end" },
      status,
    );
  }
  assertEquals(await mollieRead(molliePayment({ status: "open" })), {
    kind: "left",
  });
});

Deno.test("Mollie: a mismatch, a test payment where tests are off, a reversal or a lost connection is named and left", async () => {
  assertEquals(
    await mollieRead(molliePayment({ metadata: { reference: "PAY-OTHER" } })),
    { kind: "unreadable", reason: "mismatch" },
  );
  assertEquals(
    await mollieRead(molliePayment({ mode: "test" }), "test_x", false),
    { kind: "unreadable", reason: "mismatch" },
  );
  assertEquals(
    await mollieRead(
      molliePayment({ amountRefunded: { value: "5.00", currency: "EUR" } }),
    ),
    { kind: "unreadable", reason: "unexpected_answer" },
  );
  assertEquals(await mollieRead(new TypeError("reset")), {
    kind: "unreadable",
    reason: "unreachable",
  });
});

// ── PayPal ──────────────────────────────────────────────────────────────
const paypalCfg = { client_id: "c", secret: "s", env: "live" };
const paypalOrder = (over: Record<string, unknown>) =>
  Response.json({
    id: "O-1",
    status: "COMPLETED",
    purchase_units: [{
      payments: {
        captures: [{
          id: "CAP-1",
          status: "COMPLETED",
          amount: { value: "12.50", currency_code: "EUR" },
        }],
      },
    }],
    ...over,
  });
const token = () => Response.json({ access_token: "t" });
const paypalRead = (
  order: Response | Error,
  over: Partial<OpenIntent> = {},
  cfg: Record<string, string> = paypalCfg,
  allowTest = false,
) => {
  const p = provider({
    "/v1/oauth2/token": token(),
    "/v2/checkout/orders/": order,
  });
  return {
    p,
    read: readPaypal(intent("paypal", "O-1", over), cfg, p.deps(allowTest)),
  };
};

Deno.test("PayPal: a completed order settles its capture, a voided one ends, a created one is left", async () => {
  assertEquals(await paypalRead(paypalOrder({})).read, {
    kind: "settle",
    captureId: "CAP-1",
    fee: null,
  });
  assertEquals(await paypalRead(paypalOrder({ status: "VOIDED" })).read, {
    kind: "end",
  });
  assertEquals(
    await paypalRead(paypalOrder({ status: "CREATED", purchase_units: [] }))
      .read,
    { kind: "left" },
  );
});

/** An approved order of this intent, and what its capture answers. */
function approved(
  captureAnswer: Response | Error,
  unit: Record<string, unknown> = {},
  over: Partial<OpenIntent> = { may_capture: true },
  stillOpen: () => Promise<boolean> = () => Promise.resolve(true),
  readBack?: Response,
) {
  const order = Response.json({
    id: "O-1",
    status: "APPROVED",
    purchase_units: [{
      custom_id: "00000000-0000-4000-8000-000000004126",
      amount: { value: "12.50", currency_code: "EUR" },
      ...unit,
    }],
  });
  const p = provider({
    "/capture": captureAnswer,
    "/v1/oauth2/token": token(),
    "/v2/checkout/orders/": readBack ? [order, readBack] : order,
  });
  return {
    p,
    read: readPaypal(intent("paypal", "O-1", over), paypalCfg, {
      ...p.deps(),
      stillOpen,
    }),
  };
}

Deno.test("PayPal: an approved order whose notification never came is captured once, with the webhook's checks", async () => {
  const { p, read } = approved(paypalOrder({}));
  assertEquals(await read, { kind: "settle", captureId: "CAP-1", fee: null });
  assertEquals(
    p.seen.filter((u) => u.endsWith("/v2/checkout/orders/O-1/capture")).length,
    1,
  );
});

Deno.test("PayPal: a capture still pending is left; an approved order that is not this intent's is never captured", async () => {
  const pending = paypalOrder({
    purchase_units: [{
      payments: {
        captures: [{
          id: "CAP-1",
          status: "PENDING",
          amount: { value: "12.50", currency_code: "EUR" },
        }],
      },
    }],
  });
  assertEquals(await approved(pending).read, { kind: "left" });
  const foreign = approved(paypalOrder({}), { custom_id: "someone else" });
  assertEquals(await foreign.read, { kind: "unreadable", reason: "mismatch" });
  assertEquals(foreign.p.seen.filter((u) => u.endsWith("/capture")), []);
  const wrongAmount = approved(paypalOrder({}), {
    amount: { value: "99.00", currency_code: "EUR" },
  });
  assertEquals(await wrongAmount.read, {
    kind: "unreadable",
    reason: "mismatch",
  });
});

Deno.test("PayPal: a capture PayPal refuses or never answers is named and left", async () => {
  assertEquals(await approved(new Response("no", { status: 403 })).read, {
    kind: "unreadable",
    reason: "refused",
  });
  assertEquals(await approved(new TypeError("reset")).read, {
    kind: "unreadable",
    reason: "unreachable",
  });
});

Deno.test("PayPal: an order PayPal no longer knows ends only past its longest lifetime, and only when this job saw it under these credentials", async () => {
  const gone = () => new Response("", { status: 404 });
  const fp = await clientFingerprint(paypalCfg.client_id, paypalCfg.env);
  assertEquals(
    await paypalRead(gone(), {
      gone_may_end: true,
      seen_state: "CREATED",
      seen_client: fp,
    }).read,
    { kind: "end" },
  );
  assertEquals(
    await paypalRead(gone(), {
      gone_may_end: true,
      seen_state: "APPROVED",
      seen_client: fp,
    }).read,
    { kind: "end" },
  );
  assertEquals(
    await paypalRead(gone(), {
      gone_may_end: false,
      seen_state: "CREATED",
      seen_client: fp,
    }).read,
    { kind: "unreadable", reason: "unknown_order" },
  );
  assertEquals(
    await paypalRead(gone(), { gone_may_end: true }).read,
    { kind: "unreadable", reason: "unknown_order" },
    "never seen: named, never ended",
  );
  const otherClient = await clientFingerprint("another-client", "live");
  assertEquals(
    await paypalRead(gone(), {
      gone_may_end: true,
      seen_state: "CREATED",
      seen_client: otherClient,
    }).read,
    { kind: "unreadable", reason: "unknown_order" },
    "seen under other credentials: a change of credentials, not an expired order",
  );
});

Deno.test("PayPal: what the job saw of an order is reported with a fingerprint of the client id, never the secret", async () => {
  const p = provider({
    "/v1/oauth2/token": token(),
    "/v2/checkout/orders/": paypalOrder({
      status: "CREATED",
      purchase_units: [],
    }),
  });
  const seen: Array<{ state: string; client: string }> = [];
  await readPaypal(intent("paypal", "O-1"), {
    ...paypalCfg,
    secret: "secret-not-to-be-seen",
  }, {
    ...p.deps(),
    observe: (x) => seen.push(x),
  });
  assertEquals(seen, [{
    state: "CREATED",
    client: await clientFingerprint("c", "live"),
  }]);
  assertEquals(JSON.stringify(seen).includes("secret-not-to-be-seen"), false);
});

Deno.test("PayPal: a wrong amount, or a completed order without a completed capture, never settles", async () => {
  const wrong = paypalOrder({
    purchase_units: [{
      payments: {
        captures: [{
          id: "CAP-1",
          status: "COMPLETED",
          amount: { value: "99.00", currency_code: "EUR" },
        }],
      },
    }],
  });
  assertEquals(await paypalRead(wrong).read, {
    kind: "unreadable",
    reason: "mismatch",
  });
  const pending = paypalOrder({
    purchase_units: [{
      payments: {
        captures: [{
          id: "CAP-1",
          status: "PENDING",
          amount: { value: "12.50", currency_code: "EUR" },
        }],
      },
    }],
  });
  assertEquals(await paypalRead(pending).read, { kind: "left" });
});

Deno.test("PayPal: an unreachable PayPal is named; a sandbox configuration is not even asked where tests are off", async () => {
  const p = provider({ "/v1/oauth2/token": new Response("", { status: 503 }) });
  assertEquals(await readPaypal(intent("paypal", "O-1"), paypalCfg, p.deps()), {
    kind: "unreadable",
    reason: "unreachable",
  });
  const { p: sandbox, read } = paypalRead(paypalOrder({}), {}, {
    ...paypalCfg,
    env: "sandbox",
  });
  assertEquals(await read, { kind: "left" });
  assertEquals(sandbox.seen, []);
});

Deno.test("a settlement carries what the provider kept, for the record the notification would have made", async () => {
  const withFee = pi({
    latest_charge: {
      refunded: false,
      amount_refunded: 0,
      disputed: false,
      balance_transaction: { id: "txn_1", currency: "eur", fee: 41, net: 1209 },
    },
  });
  assertEquals(await stripeRead(session({}), withFee), {
    kind: "settle",
    captureId: "pi_1",
    fee: {
      feeCents: 41,
      netCents: 1209,
      currency: "EUR",
      transactionId: "txn_1",
    },
  });
  const captured = paypalOrder({
    purchase_units: [{
      payments: {
        captures: [{
          id: "CAP-1",
          status: "COMPLETED",
          amount: { value: "12.50", currency_code: "EUR" },
          seller_receivable_breakdown: {
            paypal_fee: { value: "0.79", currency_code: "EUR" },
            net_amount: { value: "11.71", currency_code: "EUR" },
          },
        }],
      },
    }],
  });
  assertEquals(await paypalRead(captured).read, {
    kind: "settle",
    captureId: "CAP-1",
    fee: {
      feeCents: 79,
      netCents: 1171,
      currency: "EUR",
      transactionId: "CAP-1",
    },
  });
});

Deno.test("PayPal: the capture carries the order's one request id", async () => {
  const { p, read } = approved(paypalOrder({}));
  await read;
  const i = p.seen.findIndex((u) => u.endsWith("/capture"));
  assertEquals(p.headers[i]["paypal-request-id"], "deskilo-capture-O-1");
});

Deno.test("PayPal: an order already captured is read back and settled, not captured again", async () => {
  const { p, read } = approved(
    new Response('{"details":[{"issue":"ORDER_ALREADY_CAPTURED"}]}', {
      status: 422,
    }),
    {},
    { may_capture: true },
    () => Promise.resolve(true),
    paypalOrder({}),
  );
  assertEquals(await read, { kind: "settle", captureId: "CAP-1", fee: null });
  assertEquals(p.seen.filter((u) => u.endsWith("/capture")).length, 1);
});

Deno.test("PayPal: an approved order in another currency is never captured", async () => {
  const { p, read } = approved(paypalOrder({}), {
    amount: { value: "12.50", currency_code: "USD" },
  });
  assertEquals(await read, { kind: "unreadable", reason: "mismatch" });
  assertEquals(p.seen.filter((u) => u.endsWith("/capture")), []);
});

Deno.test("PayPal: an approval older than its lifetime is named for a person, never captured", async () => {
  const { p, read } = approved(paypalOrder({}), {}, { may_capture: false });
  assertEquals(await read, {
    kind: "unreadable",
    reason: "approved_not_captured",
  });
  assertEquals(p.seen.filter((u) => u.endsWith("/capture")), []);
});

Deno.test("PayPal: an attempt closed between the claim and the capture is not captured", async () => {
  const { p, read } = approved(
    paypalOrder({}),
    {},
    { may_capture: true },
    () => Promise.resolve(false),
  );
  assertEquals(await read, { kind: "left" });
  assertEquals(p.seen.filter((u) => u.endsWith("/capture")), []);
});
