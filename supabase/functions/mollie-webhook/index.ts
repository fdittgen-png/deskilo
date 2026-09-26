// SPDX-License-Identifier: AGPL-3.0-or-later
//
// mollie-webhook — verify_jwt OFF; authenticity from FETCHING the payment
// back from Mollie with the workspace's API key (the body is untrusted).
// Credentials are PER WORKSPACE: the payment id resolves the
// payment_intents row → workspace → that workspace's Mollie key (table
// first, env fallback). Settlement is idempotent.
//
// This is the CLASSIC callback: a form body `id=tr_…` posted to the
// `webhookUrl` given at creation. Mollie's next-generation webhooks carry
// a JSON event and a signature, and are not what this endpoint was
// registered for: such a body is refused (400), never parsed into a
// payment id.
//
// #1639 — the callback's id is a notification, not proof. The fetched
// payment must be the intent's: its metadata reference, its currency and
// amount, the method the intent was opened for (a Wero intent settles
// only a Wero payment), and the key's mode (a test key never settles a
// live payment). Anything else is refused and nothing is credited.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { toMinor } from "../_shared/money.ts";
import { mollieApi, mollieKeyMode } from "../_shared/providers.ts";

type Intent = {
  workspace_id: string;
  provider: string;
  amount_cents: number;
  currency: string;
  reference: string;
};

// The key of the provider the intent was created with — Wero is offered
// through Mollie but stores its own credentials.
async function apiKey(
  admin: SupabaseClient,
  workspaceId: string,
  provider: string,
): Promise<string> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", provider)
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  return stored.api_key ?? Deno.env.get("MOLLIE_API_KEY") ?? "";
}

/** Why the fetched [payment] is not the intent's, or null when it is. */
export function mismatch(
  intent: Intent,
  payment: Record<string, unknown>,
  key: string,
): string | null {
  const metadata = (payment.metadata ?? {}) as Record<string, unknown>;
  if (metadata.reference !== intent.reference) return "reference";
  const amount = (payment.amount ?? {}) as Record<string, unknown>;
  const currency = String(amount.currency ?? "").toUpperCase();
  if (currency !== intent.currency.toUpperCase()) return "currency";
  const cents = toMinor(amount.value as string | undefined, currency);
  if (cents === null || cents !== intent.amount_cents) return "amount";
  if (intent.provider === "wero" && payment.method !== "wero") return "method";
  const mode = mollieKeyMode(key);
  if (mode === null || payment.mode !== mode) return "mode";
  return null;
}

const respond = (body: string, status: number) => new Response(body, { status });

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return respond("method_not_allowed", 405);

  const type = req.headers.get("content-type") ?? "";
  if (!type.includes("application/x-www-form-urlencoded") && !type.includes("multipart/form-data")) {
    // A next-generation event (JSON) or anything else: not this endpoint.
    return respond("unsupported_payload", 400);
  }
  const form = await req.formData().catch((error) => {
    console.warn("mollie-webhook: unreadable form body", error);
    return null;
  });
  const paymentId = form?.get("id");
  if (typeof paymentId !== "string" || !/^tr_[A-Za-z0-9_]+$/.test(paymentId)) {
    return respond("invalid_request", 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  // Mollie's webhook covers all its payments, including Wero (offered
  // through Mollie). Match either provider and settle with the actual one.
  const { data: intent } = await admin
    .from("payment_intents")
    .select("workspace_id, provider, amount_cents, currency, reference")
    .in("provider", ["mollie", "wero"])
    .eq("order_id", paymentId)
    .maybeSingle<Intent>();
  if (!intent) {
    console.log("mollie webhook: unknown payment, ignoring", paymentId);
    return respond("ok", 200);
  }
  const settleProvider = intent.provider;
  const key = await apiKey(admin, intent.workspace_id, settleProvider);
  if (!key) {
    console.log("mollie webhook not configured for workspace", intent.workspace_id);
    return respond("not_configured", 200);
  }

  let payment: Record<string, unknown>;
  try {
    const res = await fetch(
      `${mollieApi()}/v2/payments/${encodeURIComponent(paymentId)}`,
      { headers: { Authorization: `Bearer ${key}` } },
    );
    if (!res.ok) {
      // Unavailable, or unknown to Mollie under THIS key: nothing to settle,
      // and Mollie retries a non-2xx.
      console.error("mollie payment fetch failed", res.status);
      return respond("fetch_failed", 500);
    }
    payment = await res.json();
  } catch (e) {
    console.error("mollie payment fetch error", String(e));
    return respond("fetch_error", 500);
  }

  if (payment.id !== paymentId) {
    console.error("mollie answered for another payment", { paymentId, got: payment.id });
    return respond("payment_mismatch", 409);
  }

  const status = payment.status as string;
  if (status === "paid") {
    const why = mismatch(intent, payment, key);
    if (why) {
      console.error("mollie payment does not match the intent", { paymentId, why });
      return respond(`mismatch_${why}`, 409);
    }
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: settleProvider,
      p_order_id: paymentId,
      p_capture_id: paymentId,
      p_amount_cents: intent.amount_cents,
    });
    if (error) {
      console.error("mollie settle failed", error.message);
      return respond("settle_failed", 500);
    }
    console.log("mollie payment settled", { paymentId, settleProvider });
  } else if (["failed", "canceled", "expired"].includes(status)) {
    // Only a `created` intent becomes failed: a captured one keeps its money.
    await admin.rpc("mark_payment_failed", {
      p_provider: settleProvider,
      p_order_id: paymentId,
    });
    console.log("mollie payment marked failed", { paymentId, status });
  } else {
    // open, pending, authorized: not paid, and not a failure either.
    console.log("mollie webhook: not paid yet", { paymentId, status });
  }
  return respond("ok", 200);
});
