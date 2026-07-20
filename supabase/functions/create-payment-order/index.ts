// SPDX-License-Identifier: MIT
//
// create-payment-order — Edge Function (Deno) SCAFFOLDING (0043).
//
// The app calls this to start an online payment for a member's bill. It is
// the ONLY place PayPal (or any PSP) secrets live — the Flutter client
// never holds them, which keeps the F-Droid build free of proprietary
// SDKs (it only opens the approval URL this returns).
//
// STATUS: inert scaffolding. Until a deployment sets the PayPal secrets it
// replies {status: 'not_configured'} and the app shows a friendly notice.
// The real PayPal Orders v2 call is marked TODO below — see
// docs/design/payments-integration.md for the full design and go-live checklist.
//
// Deploy: supabase functions deploy create-payment-order
// Secrets: supabase secrets set PAYPAL_CLIENT_ID=... PAYPAL_SECRET=... \
//            PAYPAL_ENV=sandbox PAYPAL_RETURN_URL=https://...

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

interface OrderRequest {
  workspace_id: string;
  member_id: string;
  amount_cents: number;
  period: string;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let payload: OrderRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (
    typeof payload.amount_cents !== "number" || payload.amount_cents <= 0 ||
    !payload.workspace_id || !payload.member_id
  ) {
    return json({ error: "invalid_request" }, 400);
  }

  const clientId = Deno.env.get("PAYPAL_CLIENT_ID");
  const secret = Deno.env.get("PAYPAL_SECRET");
  // Scaffolding: no PSP secrets → the deployment has not opted in yet. The
  // app treats this as "online payments not set up" (no error surfaced).
  if (!clientId || !secret) {
    return json({ status: "not_configured" });
  }

  // TODO(payments): the real flow (docs/design/payments-integration.md §PayPal):
  //   1. OAuth: POST {PAYPAL_API}/v1/oauth2/token (client_credentials).
  //   2. Create order: POST /v2/checkout/orders with intent=CAPTURE, the
  //      amount (major units, workspace currency) and a custom_id carrying
  //      {workspace_id, member_id, period} for the webhook to reconcile.
  //   3. Persist a payment_intents row (order_id → member/period/amount) so
  //      the webhook is idempotent and auditable.
  //   4. Return the payer 'approve' HATEOAS link as approve_url.
  // Capture is confirmed asynchronously by the paypal-webhook function,
  // which posts the ledger credit via a service-role RPC — never here.
  return json({ status: "not_implemented" }, 501);
});
