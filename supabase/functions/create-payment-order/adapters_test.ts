// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the order adapters and the request parser, with the transport
// injected: no network, and no provider body ever reaches an error.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { ORDER_ADAPTERS } from "./adapters.ts";
import { failureOutcome, ProviderRefusal } from "./outcome.ts";
import { parsePaymentOrderRequest } from "./request.ts";
import type { AdapterDeps, OrderInput } from "./types.ts";

const order: OrderInput = {
  amountCents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
  key: "deskilo-intent-7",
};

function deps(
  answer: Response | Error,
  seen: { url: string; init: RequestInit }[] = [],
): AdapterDeps {
  return {
    transport: (url, init) => {
      seen.push({ url, init });
      return answer instanceof Error ? Promise.reject(answer) : Promise.resolve(answer.clone());
    },
    env: (n) => (n === "STRIPE_API_BASE" ? "http://stub" : undefined),
  };
}

Deno.test("Stripe: one request, the intent key, minor units, the injected base", async () => {
  const seen: { url: string; init: RequestInit }[] = [];
  const result = await ORDER_ADAPTERS.stripe(
    { secret_key: "sk", return_url: "https://r" },
    order,
    deps(Response.json({ id: "cs_1", url: "https://pay" }), seen),
  );
  assertEquals(result, { orderId: "cs_1", approveUrl: "https://pay" });
  assertEquals(seen.length, 1);
  assertEquals(seen[0].url, "http://stub/v1/checkout/sessions");
  const headers = seen[0].init.headers as Record<string, string>;
  assertEquals(headers["Idempotency-Key"], "deskilo-intent-7");
  assertEquals((seen[0].init.body as URLSearchParams).get("line_items[0][price_data][unit_amount]"), "1250");
});

Deno.test("a provider 4xx is a definitive refusal, a 5xx or a lost reply is unknown", async () => {
  const cfg = { secret_key: "sk", return_url: "https://r" };
  const refused = await assertRejects(
    () => ORDER_ADAPTERS.stripe(cfg, order, deps(new Response("secret body", { status: 402 }))),
    ProviderRefusal,
  );
  assertEquals(failureOutcome(refused), "failed");
  const down = await assertRejects(
    () => ORDER_ADAPTERS.stripe(cfg, order, deps(new Response("", { status: 503 }))),
    ProviderRefusal,
  );
  assertEquals(failureOutcome(down), "unknown");
  const lost = await assertRejects(
    () => ORDER_ADAPTERS.stripe(cfg, order, deps(new TypeError("connection reset"))),
  );
  assertEquals(failureOutcome(lost), "unknown");
  assertEquals(String((refused as Error).message).includes("secret"), false);
});

Deno.test("Mollie and Wero send a major-unit amount; only Wero names its method", async () => {
  const cfg = { api_key: "test_k", return_url: "https://r" };
  const reply = () => Response.json({ id: "tr_1", _links: { checkout: { href: "https://c" } } });
  const mollie: { url: string; init: RequestInit }[] = [];
  const wero: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.mollie(cfg, order, deps(reply(), mollie));
  await ORDER_ADAPTERS.wero(cfg, order, deps(reply(), wero));
  const m = JSON.parse(mollie[0].init.body as string);
  const w = JSON.parse(wero[0].init.body as string);
  assertEquals(m.amount, { currency: "EUR", value: "12.50" });
  assertEquals(m.method, undefined);
  assertEquals(w.method, "wero");
});

Deno.test("PayPal without an approve link is an error, not an order", async () => {
  const answers = [Response.json({ access_token: "t" }), Response.json({ id: "o1", links: [] })];
  const d: AdapterDeps = {
    transport: () => Promise.resolve(answers.shift()!),
    env: () => undefined,
  };
  await assertRejects(
    () =>
      ORDER_ADAPTERS.paypal(
        { client_id: "c", secret: "s", return_url: "https://r" },
        order,
        d,
      ),
    Error,
    "approve link",
  );
});

Deno.test("the request: workspace currency wins, a disagreeing body is refused", () => {
  const body = {
    provider: "stripe",
    member_id: "m",
    amount_cents: 500,
    period: "2026-10",
  };
  assertEquals(parsePaymentOrderRequest(body, "EUR").ok, true);
  const mismatch = parsePaymentOrderRequest({ ...body, currency: "usd" }, "EUR");
  assertEquals(mismatch, {
    ok: false,
    status: 400,
    body: { error: "currency_mismatch", workspace: "EUR", sent: "USD" },
  });
  for (
    const bad of [
      { ...body, provider: "constructor" },
      { ...body, amount_cents: 0 },
      { ...body, amount_cents: 1.5 },
      { ...body, request_id: "not-a-uuid" },
      { ...body, member_id: "" },
    ]
  ) {
    assertEquals(parsePaymentOrderRequest(bad, "EUR"), {
      ok: false,
      status: 400,
      body: { error: "invalid_request" },
    });
  }
});
