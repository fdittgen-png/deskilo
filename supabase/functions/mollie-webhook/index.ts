// SPDX-License-Identifier: MIT
//
// mollie-webhook — Mollie POSTs `id=<payment_id>` on status changes.
// Deployed with verify_jwt OFF; authenticity comes from FETCHING the
// payment back from Mollie's API with our MOLLIE_API_KEY (Mollie's
// documented verification pattern — the webhook body itself is untrusted).
// A paid payment settles through the service-role settle_online_payment
// RPC (idempotent per order).

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const apiKey = Deno.env.get("MOLLIE_API_KEY");
  if (!apiKey) {
    console.log("mollie webhook not configured — ignoring event");
    return new Response("not_configured", { status: 200 });
  }

  const form = await req.formData().catch(() => null);
  const paymentId = form?.get("id");
  if (typeof paymentId !== "string" || paymentId.length === 0) {
    return new Response("invalid_request", { status: 400 });
  }

  // Trust nothing from the body: fetch the payment state from Mollie.
  const res = await fetch(
    `https://api.mollie.com/v2/payments/${encodeURIComponent(paymentId)}`,
    { headers: { Authorization: `Bearer ${apiKey}` } },
  );
  if (!res.ok) {
    console.error("mollie payment fetch failed", res.status);
    return new Response("fetch_failed", { status: 500 });
  }
  const payment = await res.json();

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  if (payment.status === "paid") {
    const cents = payment.amount?.value
      ? Math.round(parseFloat(payment.amount.value) * 100)
      : null;
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "mollie",
      p_order_id: paymentId,
      p_capture_id: paymentId,
      p_amount_cents: cents,
    });
    if (error) {
      console.error("mollie settle failed", error.message);
      return new Response("settle_failed", { status: 500 });
    }
    console.log("mollie payment settled", { paymentId });
  } else if (
    ["failed", "canceled", "expired"].includes(payment.status as string)
  ) {
    await admin.rpc("mark_payment_failed", {
      p_provider: "mollie",
      p_order_id: paymentId,
    });
    console.log("mollie payment marked failed", { paymentId, status: payment.status });
  } else {
    console.log("mollie webhook ignored status", payment.status);
  }
  return new Response("ok", { status: 200 });
});
