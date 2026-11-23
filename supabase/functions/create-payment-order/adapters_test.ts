// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2595 — the order adapters and the request parser, with the transport
// injected: no network, and no provider body ever reaches an error.
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { ORDER_ADAPTERS } from "./adapters.ts";
import { withIntent } from "./mollie.ts";
import { failureOutcome, ProviderRefusal } from "./outcome.ts";
import { parsePaymentOrderRequest } from "./request.ts";
import type { AdapterDeps, OrderInput } from "./types.ts";
import { PAYER_TEXT_LIMITS, payerText } from "./payer_text.ts";

const order: OrderInput = {
  amountCents: 1250,
  currency: "EUR",
  reference: "PAY-2026-0001",
  key: "deskilo-intent-7",
  intentId: "00000000-0000-4000-8000-000000003917",
  payee: "Atelier du Marché",
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
      { ...body, invoice_ids: [] },
      { ...body, invoice_ids: ["not-a-uuid"] },
      { ...body, invoice_ids: "00000000-0000-4000-8000-000000000001" },
    ]
  ) {
    assertEquals(parsePaymentOrderRequest(bad, "EUR"), {
      ok: false,
      status: 400,
      body: { error: "invalid_request" },
    });
  }
});

Deno.test("#3917: every order carries its intent's own id back to the notifications", async () => {
  const stripe: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.stripe(
    { secret_key: "sk", return_url: "https://r" },
    order,
    deps(Response.json({ id: "cs_1", url: "https://pay" }), stripe),
  );
  assertEquals(
    (stripe[0].init.body as URLSearchParams).get("metadata[deskilo_intent]"),
    order.intentId,
  );
  assertEquals((stripe[0].init.body as URLSearchParams).get("client_reference_id"), order.reference);

  const mollie: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.mollie(
    { api_key: "test_k", return_url: "https://r", webhook_url: "https://hooks.example.test/mollie?site=a" },
    order,
    deps(Response.json({ id: "tr_1", _links: { checkout: { href: "https://c" } } }), mollie),
  );
  const m = JSON.parse(mollie[0].init.body as string);
  assertEquals(m.metadata, { reference: order.reference, deskilo_intent: order.intentId });
  const hook = new URL(m.webhookUrl);
  assertEquals(hook.searchParams.get("intent"), order.intentId);
  assertEquals(hook.searchParams.get("site"), "a", "the address keeps its own query");

  const paypal: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.paypal(
    { client_id: "c", client_secret: "s", env: "sandbox", return_url: "https://r" },
    order,
    {
      transport: (url, init) => {
        paypal.push({ url, init });
        return Promise.resolve(
          paypal.length === 1
            ? Response.json({ access_token: "t" })
            : Response.json({ id: "o1", links: [{ rel: "approve", href: "https://a" }] }),
        );
      },
      env: () => undefined,
    },
  );
  const unit = JSON.parse(paypal[1].init.body as string).purchase_units[0];
  assertEquals(unit.custom_id, order.intentId);
  assertEquals(unit.description, "Atelier du Marché — PAY-2026-0001", "the business and the reference: the payer reads it");
});

Deno.test("#3917: an overriding webhook address that already names an intent names this one, once", () => {
  const url = withIntent("https://hooks.example.test/mollie?intent=old&site=a", "new");
  const params = new URL(url).searchParams;
  assertEquals(params.getAll("intent"), ["new"]);
  assertEquals(params.get("site"), "a");
});

Deno.test("#3556: a payment names its invoices, or none as before", () => {
  const body = {
    provider: "stripe",
    member_id: "m",
    amount_cents: 500,
    period: "2026-10",
  };
  const without = parsePaymentOrderRequest(body, "EUR");
  assertEquals(without.ok && without.request.invoiceIds, null);
  const ids = [
    "00000000-0000-4000-8000-000000000001",
    "00000000-0000-4000-8000-000000000002",
  ];
  const named = parsePaymentOrderRequest({ ...body, invoice_ids: ids }, "EUR");
  assertEquals(named.ok && named.request.invoiceIds, ids);
  assertEquals(named.ok && named.request.standalone, false);
});

Deno.test("#4165: a standalone payment has no month, and names its invoices and request id", () => {
  const ids = ["00000000-0000-4000-8000-000000000001"];
  const body = {
    provider: "stripe",
    member_id: "m",
    amount_cents: 500,
    standalone: true,
    invoice_ids: ids,
    request_id: "00000000-0000-4000-8000-0000000000aa",
  };
  const ok = parsePaymentOrderRequest(body, "EUR");
  assertEquals(ok.ok && ok.request.standalone, true);
  assertEquals(ok.ok && ok.request.period, "");
  for (const missing of ["invoice_ids", "request_id"]) {
    const bad: Record<string, unknown> = { ...body };
    delete bad[missing];
    assertEquals(parsePaymentOrderRequest(bad, "EUR").ok, false, missing);
  }
});

/** What each provider receives as the text its payer reads, for [payee]. */
async function payerTexts(payee: string) {
  const o = { ...order, payee };
  const stripe: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.stripe(
    { secret_key: "sk", return_url: "https://r" },
    o,
    deps(Response.json({ id: "cs_1", url: "https://pay" }), stripe),
  );
  const mollie: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.mollie(
    { api_key: "test_k", return_url: "https://r" },
    o,
    deps(Response.json({ id: "tr_1", _links: { checkout: { href: "https://c" } } }), mollie),
  );
  const paypal: { url: string; init: RequestInit }[] = [];
  await ORDER_ADAPTERS.paypal(
    { client_id: "c", client_secret: "s", env: "sandbox", return_url: "https://r" },
    o,
    {
      transport: (url, init) => {
        paypal.push({ url, init });
        return Promise.resolve(
          paypal.length === 1
            ? Response.json({ access_token: "t" })
            : Response.json({ id: "o1", links: [{ rel: "approve", href: "https://a" }] }),
        );
      },
      env: () => undefined,
    },
  );
  return {
    stripe: (stripe[0].init.body as URLSearchParams).get("line_items[0][price_data][product_data][name]")!,
    mollie: JSON.parse(mollie[0].init.body as string).description as string,
    paypal: JSON.parse(paypal[1].init.body as string).purchase_units[0].description as string,
  };
}

Deno.test("#4135: every provider shows the payer the business's name and the reference", async () => {
  const texts = await payerTexts("Atelier du Marché");
  assertEquals(texts, {
    stripe: "Atelier du Marché — PAY-2026-0001",
    mollie: "Atelier du Marché — PAY-2026-0001",
    paypal: "Atelier du Marché — PAY-2026-0001",
  });
});

Deno.test("#4135: a long name is shortened within each provider's limit, the reference never", async () => {
  const texts = await payerTexts("Coworking ".repeat(40).trim());
  for (const [provider, text] of Object.entries(texts)) {
    const limit = PAYER_TEXT_LIMITS[provider as keyof typeof PAYER_TEXT_LIMITS];
    assertEquals([...text].length <= limit, true, `${provider}: ${[...text].length} > ${limit}`);
    assertEquals(text.endsWith("… — PAY-2026-0001"), true, provider);
  }
});

Deno.test("#4135: characters a provider refuses never reach it", async () => {
  const texts = await payerTexts("Atelier\n du\u0000 Marché\u200b");
  for (const text of Object.values(texts)) {
    assertEquals(text, "Atelier du Marché — PAY-2026-0001");
  }
});

Deno.test("#4135: without a name, the reference alone", () => {
  assertEquals(payerText("", "PAY-2026-0001", PAYER_TEXT_LIMITS.paypal), "PAY-2026-0001");
  assertEquals(payerText("   ", "PAY-2026-0001", PAYER_TEXT_LIMITS.paypal), "PAY-2026-0001");
});
