// SPDX-License-Identifier: MIT
//
// paypal-webhook — Edge Function (Deno) SCAFFOLDING (0043).
//
// PayPal calls this when a payment is captured. It VERIFIES the webhook
// signature, then reconciles the capture into the ledger by calling a
// service-role RPC (settle_online_payment) — the capture itself is the
// proof of payment, so no second-person confirmation is needed.
//
// STATUS: inert scaffolding. Verification + settlement are TODO; see
// docs/design/payments-integration.md §Reconciliation. Without PAYPAL_WEBHOOK_ID
// it acknowledges 200 without acting, so a misconfigured webhook never
// posts phantom credits.
//
// Deploy WITHOUT JWT verification (PayPal has no Supabase JWT):
//   supabase functions deploy paypal-webhook --no-verify-jwt

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const webhookId = Deno.env.get("PAYPAL_WEBHOOK_ID");
  if (!webhookId) {
    // Not configured yet — acknowledge so PayPal stops retrying, but act on
    // nothing.
    return new Response("not_configured", { status: 200 });
  }

  // TODO(payments) (docs/design/payments-integration.md §Reconciliation):
  //   1. Verify the event: POST /v1/notifications/verify-webhook-signature
  //      with the transmission headers + PAYPAL_WEBHOOK_ID. Reject on
  //      verification_status != SUCCESS.
  //   2. On PAYMENT.CAPTURE.COMPLETED, read custom_id → {workspace_id,
  //      member_id, period} and the captured amount + capture_id.
  //   3. Call settle_online_payment(capture_id, workspace, member, amount,
  //      period) with the SERVICE ROLE key — idempotent on capture_id, it
  //      inserts a confirmed 'payment' ledger credit. Ignore duplicates.
  //   4. Return 200 quickly; PayPal retries non-2xx.
  return new Response("not_implemented", { status: 501 });
});
