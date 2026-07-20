// SPDX-License-Identifier: MIT
//
// paypal-webhook — PayPal calls this on capture events. Deployed with
// verify_jwt OFF (PayPal holds no Supabase JWT); authenticity comes from
// PayPal's own webhook-signature verification against PAYPAL_WEBHOOK_ID.
// On PAYMENT.CAPTURE.COMPLETED the capture settles through the
// service-role settle_online_payment RPC (idempotent per order).

import { createClient } from "npm:@supabase/supabase-js@2";

const paypalApi = () =>
  Deno.env.get("PAYPAL_ENV") === "live"
    ? "https://api-m.paypal.com"
    : "https://api-m.sandbox.paypal.com";

async function accessToken(): Promise<string> {
  const auth = btoa(
    `${Deno.env.get("PAYPAL_CLIENT_ID")}:${Deno.env.get("PAYPAL_SECRET")}`,
  );
  const res = await fetch(`${paypalApi()}/v1/oauth2/token`, {
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

  const webhookId = Deno.env.get("PAYPAL_WEBHOOK_ID");
  if (!webhookId || !Deno.env.get("PAYPAL_CLIENT_ID")) {
    // Not configured: acknowledge so PayPal stops retrying, act on nothing.
    console.log("paypal webhook not configured — ignoring event");
    return new Response("not_configured", { status: 200 });
  }

  const rawBody = await req.text();
  let event: Record<string, unknown>;
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("invalid_json", { status: 400 });
  }

  // 1. Verify the transmission against PayPal before trusting anything.
  try {
    const token = await accessToken();
    const verifyRes = await fetch(
      `${paypalApi()}/v1/notifications/verify-webhook-signature`,
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
          webhook_id: webhookId,
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

  // 2. Settle completed captures; mark denials failed.
  const type = event.event_type as string;
  const resource = (event.resource ?? {}) as Record<string, unknown>;
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const orderId =
    ((resource.supplementary_data as Record<string, unknown> | undefined)
      ?.related_ids as Record<string, unknown> | undefined)?.order_id ??
      resource.id;

  if (type === "PAYMENT.CAPTURE.COMPLETED") {
    const amount = resource.amount as { value?: string } | undefined;
    const cents = amount?.value
      ? Math.round(parseFloat(amount.value) * 100)
      : null;
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "paypal",
      p_order_id: String(orderId),
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
      p_order_id: String(orderId),
    });
    console.log("paypal payment marked failed", { orderId, type });
  } else {
    console.log("paypal webhook ignored event", type);
  }
  return new Response("ok", { status: 200 });
});
