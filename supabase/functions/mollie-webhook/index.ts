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
// only a Wero payment), and a live payment under a live key (#3905: a
// test-mode payment never credits a ledger). Anything else is refused and
// nothing is credited (_shared/mollie_payment_rules.ts). A paid payment shown charged back
// or refunded is recorded as reversed instead.

import { configOf } from "../_shared/webhook_guard.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { mollieApi } from "../_shared/providers.ts";
import { type Intent, mismatch, reversalOf } from "../_shared/mollie_payment_rules.ts";
import { allowsTestPayments } from "../_shared/test_payments.ts";
import { attachOrder, INTENT_KEY, intentIdOf, provisionalIntent } from "../_shared/provisional_intent.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { guard } from "../_shared/serve.ts";

const FN = "mollie-webhook";

// The key of the provider the intent was created with — Wero is offered
// through Mollie but stores its own credentials.
async function apiKey(
  admin: SupabaseClient,
  workspaceId: string,
  provider: string,
  env: (name: string) => string | undefined,
): Promise<string> {
  // #3093 E6 — a failed read throws; the caller answers 500, never the
  // installation's key for a workspace that has its own.
  const stored = configOf(
    await admin
      .from("payment_credentials")
      .select("config")
      .eq("workspace_id", workspaceId)
      .eq("provider", provider)
      .maybeSingle(),
  );
  return stored.api_key ?? env("MOLLIE_API_KEY") ?? "";
}

const respond = (body: string, status: number) => new Response(body, { status });

/** What the handler is injected with, so a test drives it (#3917). */
export interface Deps {
  admin: () => SupabaseClient;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  allowTest: () => boolean;
}

const defaultDeps: Deps = {
  admin: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ),
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  allowTest: () => allowsTestPayments(),
};

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method !== "POST") return respond("method_not_allowed", 405);

  const type = req.headers.get("content-type") ?? "";
  if (!type.includes("application/x-www-form-urlencoded") && !type.includes("multipart/form-data")) {
    // A next-generation event (JSON) or anything else: not this endpoint.
    return respond("unsupported_payload", 400);
  }
  const form = await req.formData().catch((error) => {
    logLine("warn", FN, "unreadable_form_body", { error: describeError(error) });
    return null;
  });
  const paymentId = form?.get("id");
  if (typeof paymentId !== "string" || !/^tr_[A-Za-z0-9_]+$/.test(paymentId)) {
    return respond("invalid_request", 400);
  }

  const admin = deps.admin();
  // Mollie's webhook covers all its payments, including Wero (offered
  // through Mollie). Match either provider and settle with the actual one.
  const byOrderOnce = () =>
    admin
      .from("payment_intents")
      .select("workspace_id, provider, amount_cents, currency, reference")
      .in("provider", ["mollie", "wero"])
      .eq("order_id", paymentId)
      .maybeSingle<Intent>();
  const { data: byOrder, error: lookupError } = await byOrderOnce();
  if (lookupError) {
    logLine("error", FN, "intent_lookup_failed");
    return respond("lookup_failed", 500);
  }
  // #3917 -- an intent whose provider answer was uncertain does not know its
  // payment yet: the webhook address names it, and the payment is attached
  // once Mollie, asked with the business's own key, confirms the payment
  // carries that intent.
  let intent: Intent | null = byOrder;
  let attach: string | null = null;
  const named = intentIdOf(new URL(req.url).searchParams.get("intent"));
  if (!intent) {
    const provisional = await provisionalIntent<Intent & { id: string }>(
      admin,
      ["mollie", "wero"],
      named,
      "id, workspace_id, provider, amount_cents, currency, reference",
    );
    if (provisional.error) {
      logLine("error", FN, "intent_lookup_failed");
      return respond("lookup_failed", 500);
    }
    intent = provisional.data;
    attach = provisional.data?.id ?? null;
  }
  if (!intent && named) {
    // The order request's own late write may have stored the payment between
    // the two reads: read it by the payment once more.
    const again = await byOrderOnce();
    if (again.error) {
      logLine("error", FN, "intent_lookup_failed");
      return respond("lookup_failed", 500);
    }
    intent = again.data;
  }
  if (!intent) {
    logLine("info", FN, "unknown_payment_ignoring", { paymentId });
    return respond("ok", 200);
  }
  const settleProvider = intent.provider;
  let key: string;
  try {
    key = await apiKey(admin, intent.workspace_id, settleProvider, deps.env);
  } catch (e) {
    logLine("error", FN, "credential_read_failed", { error: describeError(e) });
    return respond("config_unavailable", 500);
  }
  if (!key) {
    logLine("info", FN, "not_configured_for_workspace", { workspace_id: intent.workspace_id });
    return respond("not_configured", 200);
  }

  let payment: Record<string, unknown>;
  try {
    const res = await deps.fetch(
      `${mollieApi()}/v2/payments/${encodeURIComponent(paymentId)}`,
      { headers: { Authorization: `Bearer ${key}` } },
    );
    if (!res.ok) {
      // Unavailable, or unknown to Mollie under THIS key: nothing to settle,
      // and Mollie retries a non-2xx.
      logLine("error", FN, "payment_fetch_failed", { status: res.status });
      return respond("fetch_failed", 500);
    }
    payment = await res.json();
  } catch (e) {
    logLine("error", FN, "payment_fetch_error", { error: describeError(e) });
    return respond("fetch_error", 500);
  }

  if (payment.id !== paymentId) {
    logLine("error", FN, "answered_for_another_payment", { paymentId, got: payment.id });
    return respond("payment_mismatch", 409);
  }
  if (attach) {
    // The payment must carry the intent the address named: an address can
    // be guessed, the business's own payment cannot.
    const carried = (payment.metadata as Record<string, unknown> | undefined)?.[INTENT_KEY];
    if (carried !== attach) {
      logLine("info", FN, "intent_not_carried", { paymentId });
      return respond("ok", 200);
    }
    const { error, outcome } = await attachOrder(admin, attach, paymentId);
    if (error) {
      logLine("error", FN, "order_attach_failed");
      return respond("attach_failed", 500);
    }
    if (outcome === "other") {
      logLine("info", FN, "intent_holds_another_payment", { paymentId });
      return respond("ok", 200);
    }
    logLine("info", FN, "payment_attached_to_its_intent", { paymentId, outcome });
  }

  const status = payment.status as string;
  if (status === "paid") {
    const why = mismatch(intent, payment, key, deps.allowTest());
    if (why) {
      logLine("error", FN, "payment_does_not_match_the_intent", { paymentId, why });
      return respond(`mismatch_${why}`, 409);
    }
    // #3905 -- charged back or refunded: recorded as reversed, never settled.
    const reversal = reversalOf(payment);
    if (reversal) {
      const { error: markError } = await admin.rpc("mark_payment_reversed", {
        p_provider: settleProvider,
        p_order_id: paymentId,
        p_reason: reversal,
      });
      if (markError) {
        logLine("error", FN, "reversal_record_failed", { error: describeError(markError) });
        return respond("reversal_record_failed", 500);
      }
      logLine("info", FN, "payment_reversed", { paymentId, reversal });
      return respond("ok", 200);
    }
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: settleProvider,
      p_order_id: paymentId,
      p_capture_id: paymentId,
      p_amount_cents: intent.amount_cents,
    });
    if (error) {
      logLine("error", FN, "settle_failed", { error: describeError(error) });
      return respond("settle_failed", 500);
    }
    logLine("info", FN, "payment_settled", { paymentId, settleProvider });
  } else if (["failed", "canceled", "expired"].includes(status)) {
    // Only a `created` intent becomes failed: a captured one keeps its money.
    await admin.rpc("mark_payment_failed", {
      p_provider: settleProvider,
      p_order_id: paymentId,
    });
    logLine("info", FN, "payment_marked_failed", { paymentId, status });
  } else {
    // open, pending, authorized: not paid, and not a failure either.
    logLine("info", FN, "not_paid_yet", { paymentId, status });
  }
  return respond("ok", 200);
}

/** The function as it is served: whatever [handle] throws is the envelope (#4412). */
export const serve = (deps: Deps = defaultDeps) => guard(FN, (req) => handle(req, deps));

if (import.meta.main) Deno.serve(serve());
