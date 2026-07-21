// SPDX-License-Identifier: MIT
//
// mollie-webhook — verify_jwt OFF; authenticity from FETCHING the payment
// back from Mollie with the workspace's API key (the body is untrusted).
// Credentials are PER WORKSPACE: the payment id resolves the
// payment_intents row → workspace → that workspace's Mollie key (table
// first, env fallback). Settlement is idempotent.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

async function apiKey(
  admin: SupabaseClient,
  workspaceId: string,
): Promise<string> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "mollie")
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  return stored.api_key ?? Deno.env.get("MOLLIE_API_KEY") ?? "";
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const form = await req.formData().catch(() => null);
  const paymentId = form?.get("id");
  if (typeof paymentId !== "string" || paymentId.length === 0) {
    return new Response("invalid_request", { status: 400 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  // Mollie's webhook covers all its payments, including Wero (offered
  // through Mollie). Match either provider and settle with the actual one.
  const { data: intent } = await admin
    .from("payment_intents")
    .select("workspace_id, provider")
    .in("provider", ["mollie", "wero"])
    .eq("order_id", paymentId)
    .maybeSingle();
  if (!intent) {
    console.log("mollie webhook: unknown payment, ignoring", paymentId);
    return new Response("ok", { status: 200 });
  }
  const settleProvider = intent.provider as string;
  const key = await apiKey(admin, intent.workspace_id);
  if (!key) {
    console.log("mollie webhook not configured for workspace", intent.workspace_id);
    return new Response("not_configured", { status: 200 });
  }

  const res = await fetch(
    `https://api.mollie.com/v2/payments/${encodeURIComponent(paymentId)}`,
    { headers: { Authorization: `Bearer ${key}` } },
  );
  if (!res.ok) {
    console.error("mollie payment fetch failed", res.status);
    return new Response("fetch_failed", { status: 500 });
  }
  const payment = await res.json();

  if (payment.status === "paid") {
    const cents = payment.amount?.value
      ? Math.round(parseFloat(payment.amount.value) * 100)
      : null;
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: settleProvider,
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
      p_provider: settleProvider,
      p_order_id: paymentId,
    });
    console.log("mollie payment marked failed", { paymentId, status: payment.status });
  } else {
    console.log("mollie webhook ignored status", payment.status);
  }
  return new Response("ok", { status: 200 });
});
