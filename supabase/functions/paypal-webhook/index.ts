// SPDX-License-Identifier: MIT
//
// paypal-webhook — verify_jwt OFF; authenticity from PayPal's own
// webhook-signature verification. Credentials are PER WORKSPACE: the
// event's order id resolves the payment_intents row → workspace →
// that workspace's PayPal config (table first, env fallback). Settlement
// goes through the service-role settle_online_payment RPC (idempotent).

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

async function paypalConfig(
  admin: SupabaseClient,
  workspaceId: string,
): Promise<Record<string, string>> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "paypal")
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  return {
    client_id: stored.client_id ?? Deno.env.get("PAYPAL_CLIENT_ID") ?? "",
    secret: stored.secret ?? Deno.env.get("PAYPAL_SECRET") ?? "",
    env: stored.env ?? Deno.env.get("PAYPAL_ENV") ?? "sandbox",
    webhook_id: stored.webhook_id ?? Deno.env.get("PAYPAL_WEBHOOK_ID") ?? "",
  };
}

const paypalApi = (env: string) =>
  env === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

async function accessToken(cfg: Record<string, string>): Promise<string> {
  const auth = btoa(`${cfg.client_id}:${cfg.secret}`);
  const res = await fetch(`${paypalApi(cfg.env)}/v1/oauth2/token`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`paypal oauth ${res.status}`);
  return (await res.json()).access_token;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(await req.text());
  } catch {
    return new Response("invalid_json", { status: 400 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const resource = (event.resource ?? {}) as Record<string, unknown>;
  const orderId = String(
    ((resource.supplementary_data as Record<string, unknown> | undefined)
      ?.related_ids as Record<string, unknown> | undefined)?.order_id ??
      resource.id ?? "",
  );

  // Resolve the workspace from the intent, then load ITS PayPal config.
  const { data: intent } = await admin
    .from("payment_intents")
    .select("workspace_id")
    .eq("provider", "paypal")
    .eq("order_id", orderId)
    .maybeSingle();
  if (!intent) {
    console.log("paypal webhook: unknown order, ignoring", orderId);
    return new Response("ok", { status: 200 });
  }
  const cfg = await paypalConfig(admin, intent.workspace_id);
  if (!cfg.webhook_id || !cfg.client_id) {
    console.log("paypal webhook not configured for workspace", intent.workspace_id);
    return new Response("not_configured", { status: 200 });
  }

  // Verify the transmission against PayPal before trusting anything.
  try {
    const token = await accessToken(cfg);
    const verifyRes = await fetch(
      `${paypalApi(cfg.env)}/v1/notifications/verify-webhook-signature`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          transmission_id: req.headers.get("paypal-transmission-id"),
          transmission_time: req.headers.get("paypal-transmission-time"),
          cert_url: req.headers.get("paypal-cert-url"),
          auth_algo: req.headers.get("paypal-auth-algo"),
          transmission_sig: req.headers.get("paypal-transmission-sig"),
          webhook_id: cfg.webhook_id,
          webhook_event: event,
        }),
      },
    );
    const verification = await verifyRes.json();
    if (verification.verification_status !== "SUCCESS") {
      console.error("paypal webhook verification FAILED", verification);
      return new Response("verification_failed", { status: 400 });
    }
  } catch (e) {
    console.error("paypal webhook verification error", String(e));
    return new Response("verification_error", { status: 500 });
  }

  const type = event.event_type as string;
  if (type === "PAYMENT.CAPTURE.COMPLETED") {
    const amount = resource.amount as { value?: string } | undefined;
    const cents = amount?.value
      ? Math.round(parseFloat(amount.value) * 100)
      : null;
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "paypal",
      p_order_id: orderId,
      p_capture_id: String(resource.id),
      p_amount_cents: cents,
    });
    if (error) {
      console.error("paypal settle failed", error.message);
      return new Response("settle_failed", { status: 500 });
    }
    console.log("paypal capture settled", { orderId, capture: resource.id });
  } else if (
    type === "PAYMENT.CAPTURE.DENIED" || type === "CHECKOUT.ORDER.VOIDED"
  ) {
    await admin.rpc("mark_payment_failed", {
      p_provider: "paypal",
      p_order_id: orderId,
    });
    console.log("paypal payment marked failed", { orderId, type });
  } else {
    console.log("paypal webhook ignored event", type);
  }
  return new Response("ok", { status: 200 });
});
