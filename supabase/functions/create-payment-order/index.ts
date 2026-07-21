// SPDX-License-Identifier: MIT
//
// create-payment-order — starts a REAL online payment for a member's bill
// (docs/design/payments-integration.md). Providers: PayPal (Orders v2),
// Stripe (Checkout), Mollie (Payments).
//
// Credentials are PER WORKSPACE, configured from the owner UI and stored in
// the deny-all `payment_credentials` table (read here via the service role);
// deployment-wide env vars are the fallback. A provider whose required
// config is absent is not offered: {action:'config', workspace_id} lists the
// configured providers and, per provider, the missing config fields.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

type Provider = "paypal" | "stripe" | "mollie";

/** Config field → env-var fallback, per provider. */
const FIELD_ENV: Record<Provider, Record<string, string>> = {
  paypal: {
    client_id: "PAYPAL_CLIENT_ID",
    secret: "PAYPAL_SECRET",
    env: "PAYPAL_ENV",
    webhook_id: "PAYPAL_WEBHOOK_ID",
    return_url: "PAYMENT_RETURN_URL",
  },
  stripe: {
    secret_key: "STRIPE_SECRET_KEY",
    webhook_secret: "STRIPE_WEBHOOK_SECRET",
    return_url: "PAYMENT_RETURN_URL",
  },
  mollie: {
    api_key: "MOLLIE_API_KEY",
    return_url: "PAYMENT_RETURN_URL",
  },
};

/** Fields a provider must have before it can be offered. */
const REQUIRED: Record<Provider, string[]> = {
  paypal: ["client_id", "secret", "return_url"],
  stripe: ["secret_key", "return_url"],
  mollie: ["api_key", "return_url"],
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const major = (cents: number) => (cents / 100).toFixed(2);

/** The effective config of a provider for a workspace: table row (owner UI)
 * overlaid on env-var fallbacks, per field. */
async function effectiveConfig(
  admin: SupabaseClient,
  workspaceId: string,
  provider: Provider,
): Promise<Record<string, string>> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", provider)
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  const out: Record<string, string> = {};
  for (const [field, envVar] of Object.entries(FIELD_ENV[provider])) {
    const value = stored[field] ?? Deno.env.get(envVar) ?? "";
    if (value) out[field] = value;
  }
  return out;
}

const missingFields = (config: Record<string, string>, provider: Provider) =>
  REQUIRED[provider].filter((f) => !config[f]);

const paypalApi = (env?: string) =>
  env === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

// ── providers ─────────────────────────────────────────────────────────

async function createPaypalOrder(
  cfg: Record<string, string>,
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const auth = btoa(`${cfg.client_id}:${cfg.secret}`);
  const tokenRes = await fetch(`${paypalApi(cfg.env)}/v1/oauth2/token`, {
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
  const orderRes = await fetch(`${paypalApi(cfg.env)}/v2/checkout/orders`, {
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
        return_url: cfg.return_url,
        cancel_url: cfg.return_url,
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
  cfg: Record<string, string>,
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const params = new URLSearchParams({
    mode: "payment",
    success_url: cfg.return_url,
    cancel_url: cfg.return_url,
    client_reference_id: reference,
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": currency.toLowerCase(),
    "line_items[0][price_data][unit_amount]": String(amountCents),
    "line_items[0][price_data][product_data][name]": `DesKilo ${reference}`,
  });
  const res = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cfg.secret_key}`,
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
  cfg: Record<string, string>,
  amountCents: number,
  currency: string,
  reference: string,
): Promise<{ orderId: string; approveUrl: string }> {
  const res = await fetch("https://api.mollie.com/v2/payments", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${cfg.api_key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      amount: { currency, value: major(amountCents) },
      description: `DesKilo ${reference}`,
      redirectUrl: cfg.return_url,
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

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const workspaceId = body.workspace_id as string;
  if (!workspaceId) return json({ error: "invalid_request" }, 400);

  // Config probe: which providers can THIS workspace charge with?
  if (body.action === "config") {
    const providers: Provider[] = [];
    const missing: Record<string, string[]> = {};
    for (const provider of Object.keys(REQUIRED) as Provider[]) {
      const cfg = await effectiveConfig(admin, workspaceId, provider);
      const gap = missingFields(cfg, provider);
      missing[provider] = gap;
      if (gap.length === 0) providers.push(provider);
    }
    console.log("payment config probe", { workspaceId, providers, missing });
    return json({ providers, missing });
  }

  const provider = body.provider as Provider;
  const memberId = body.member_id as string;
  const amountCents = body.amount_cents as number;
  const currency = ((body.currency as string) ?? "EUR").toUpperCase();
  const period = body.period as string;
  if (
    !provider || !(provider in REQUIRED) || !memberId ||
    typeof amountCents !== "number" || amountCents <= 0 || !period
  ) {
    return json({ error: "invalid_request" }, 400);
  }

  const cfg = await effectiveConfig(admin, workspaceId, provider);
  const gap = missingFields(cfg, provider);
  if (gap.length > 0) {
    console.log("payment provider not configured", { provider, gap });
    return json({ status: "not_configured", provider, missing: gap });
  }

  // AuthZ: the JWT's user must BE the member they pay for.
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
      ? await createPaypalOrder(cfg, amountCents, currency, reference)
      : provider === "stripe"
      ? await createStripeSession(cfg, amountCents, currency, reference)
      : await createMolliePayment(cfg, amountCents, currency, reference);

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
    const detail = e instanceof Error ? e.message : String(e);
    console.error("payment order failed", { provider, detail });
    return json({ error: "provider_error", provider, detail }, 502);
  }
});
