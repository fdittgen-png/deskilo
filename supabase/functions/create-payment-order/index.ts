// SPDX-License-Identifier: MIT
//
// create-payment-order — starts a REAL online payment for a member's bill
// (docs/design/payments-integration.md). Three providers:
//
//   paypal  — Orders v2 (PAYPAL_CLIENT_ID, PAYPAL_SECRET, PAYPAL_ENV)
//   stripe  — Checkout Session, cards/SEPA/… (STRIPE_SECRET_KEY)
//   mollie  — Payments API, iDEAL/Bancontact/cards/… (MOLLIE_API_KEY)
//
// All providers also need PAYMENT_RETURN_URL (where the payer lands after
// approving). A provider whose secrets are absent is simply NOT offered:
// {action:'config'} lists the configured ones, and starting an order on an
// unconfigured provider answers {status:'not_configured', missing:[…]} so
// the app can say exactly what the deployment lacks.
//
// Capture confirmation is asynchronous via the per-provider webhook
// functions, which settle through the service-role settle_online_payment
// RPC — this function only creates the order and the payment_intents row.
//
// Deploy: verify_jwt ON (members call it with their session token).
// Secrets: supabase secrets set PAYPAL_CLIENT_ID=… PAYPAL_SECRET=… \
//   PAYPAL_ENV=sandbox STRIPE_SECRET_KEY=… MOLLIE_API_KEY=… \
//   PAYMENT_RETURN_URL=https://…

import { createClient } from "npm:@supabase/supabase-js@2";

type Provider = "paypal" | "stripe" | "mollie";

const RETURN_URL = Deno.env.get("PAYMENT_RETURN_URL") ?? "";

/** Env keys each provider needs before it is offered at all. */
const REQUIRED: Record<Provider, string[]> = {
  paypal: ["PAYPAL_CLIENT_ID", "PAYPAL_SECRET", "PAYMENT_RETURN_URL"],
  stripe: ["STRIPE_SECRET_KEY", "PAYMENT_RETURN_URL"],
  mollie: ["MOLLIE_API_KEY", "PAYMENT_RETURN_URL"],
};

const missingFor = (provider: Provider): string[] =>
  REQUIRED[provider].filter((key) => !Deno.env.get(key));

const configuredProviders = (): Provider[] =>
  (Object.keys(REQUIRED) as Provider[]).filter(
    (p) => missingFor(p).length === 0,
  );

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const paypalApi = () =>
  Deno.env.get("PAYPAL_ENV") === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

/** Cents → major-unit string with two decimals ('12.34'). */
const major = (cents: number) => (cents / 100).toFixed(2);

// ── providers ─────────────────────────────────────────────────────────

async function createPaypalOrder(
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const auth = btoa(
    `${Deno.env.get("PAYPAL_CLIENT_ID")}:${Deno.env.get("PAYPAL_SECRET")}`,
  );
  const tokenRes = await fetch(`${paypalApi()}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!tokenRes.ok) {
    throw new Error(`paypal oauth ${tokenRes.status}: ${await tokenRes.text()}`);
  }
  const { access_token } = await tokenRes.json();

  const orderRes = await fetch(`${paypalApi()}/v2/checkout/orders`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${access_token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      intent: "CAPTURE",
      purchase_units: [{
        amount: { currency_code: currency, value: major(amountCents) },
        custom_id: reference,
      }],
      application_context: {
        return_url: RETURN_URL,
        cancel_url: RETURN_URL,
        user_action: "PAY_NOW",
      },
    }),
  });
  if (!orderRes.ok) {
    throw new Error(`paypal order ${orderRes.status}: ${await orderRes.text()}`);
  }
  const order = await orderRes.json();
  const approve = (order.links ?? []).find(
    (l: { rel: string }) => l.rel === "approve",
  );
  if (!approve) throw new Error("paypal order has no approve link");
  return { orderId: order.id, approveUrl: approve.href };
}

async function createStripeSession(
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const params = new URLSearchParams({
    mode: "payment",
    success_url: RETURN_URL,
    cancel_url: RETURN_URL,
    client_reference_id: reference,
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": currency.toLowerCase(),
    "line_items[0][price_data][unit_amount]": String(amountCents),
    "line_items[0][price_data][product_data][name]": `DesKilo ${reference}`,
  });
  const res = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("STRIPE_SECRET_KEY")}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params,
  });
  if (!res.ok) {
    throw new Error(`stripe session ${res.status}: ${await res.text()}`);
  }
  const session = await res.json();
  return { orderId: session.id, approveUrl: session.url };
}

async function createMolliePayment(
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const res = await fetch("https://api.mollie.com/v2/payments", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${Deno.env.get("MOLLIE_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: { currency, value: major(amountCents) },
      description: `DesKilo ${reference}`,
      redirectUrl: RETURN_URL,
      metadata: { reference },
    }),
  });
  if (!res.ok) {
    throw new Error(`mollie payment ${res.status}: ${await res.text()}`);
  }
  const payment = await res.json();
  return { orderId: payment.id, approveUrl: payment._links.checkout.href };
}

// ── handler ───────────────────────────────────────────────────────────

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  // Config probe: which providers can this deployment actually charge with?
  if (body.action === "config") {
    const providers = configuredProviders();
    const missing = Object.fromEntries(
      (Object.keys(REQUIRED) as Provider[]).map((p) => [p, missingFor(p)]),
    );
    console.log("payment config probe", { providers, missing });
    return json({ providers, missing });
  }

  const provider = body.provider as Provider;
  const workspaceId = body.workspace_id as string;
  const memberId = body.member_id as string;
  const amountCents = body.amount_cents as number;
  const currency = ((body.currency as string) ?? "EUR").toUpperCase();
  const period = body.period as string;
  if (
    !provider || !(provider in REQUIRED) || !workspaceId || !memberId ||
    typeof amountCents !== "number" || amountCents <= 0 || !period
  ) {
    return json({ error: "invalid_request" }, 400);
  }

  const missing = missingFor(provider);
  if (missing.length > 0) {
    console.log("payment provider not configured", { provider, missing });
    return json({ status: "not_configured", provider, missing });
  }

  // AuthZ: the JWT's user must BE the member they pay for.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const token = (req.headers.get("Authorization") ?? "").replace(
    "Bearer ",
    "",
  );
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    console.error("payment auth failed", userError?.message);
    return json({ error: "unauthorized" }, 401);
  }
  const { data: member } = await admin
    .from("members")
    .select("id, user_id, workspace_id, status")
    .eq("id", memberId)
    .single();
  if (
    !member || member.user_id !== userData.user.id ||
    member.workspace_id !== workspaceId || member.status !== "active"
  ) {
    console.error("payment member mismatch", { memberId, workspaceId });
    return json({ error: "not_your_bill" }, 403);
  }

  const reference = `${workspaceId}:${memberId}:${period}`;
  try {
    const order = provider === "paypal"
      ? await createPaypalOrder(amountCents, currency, reference)
      : provider === "stripe"
      ? await createStripeSession(amountCents, currency, reference)
      : await createMolliePayment(amountCents, currency, reference);

    const { error: insertError } = await admin.from("payment_intents").insert({
      workspace_id: workspaceId,
      member_id: memberId,
      provider,
      order_id: order.orderId,
      period,
      amount_cents: amountCents,
      currency,
    });
    if (insertError) {
      console.error("payment intent insert failed", insertError.message);
      return json({ error: "intent_insert_failed" }, 500);
    }

    console.log("payment order created", {
      provider,
      orderId: order.orderId,
      amountCents,
      currency,
      period,
    });
    return json({
      status: "created",
      provider,
      order_id: order.orderId,
      approve_url: order.approveUrl,
    });
  } catch (e) {
    // Full detail into the function logs AND back to the app's trace.
    const detail = e instanceof Error ? e.message : String(e);
    console.error("payment order failed", { provider, detail });
    return json({ error: "provider_error", provider, detail }, 502);
  }
});
