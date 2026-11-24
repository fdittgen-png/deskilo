// SPDX-License-Identifier: AGPL-3.0-or-later
//
// paypal-webhook — verify_jwt OFF; authenticity from PayPal's own
// webhook-signature verification. Credentials are PER WORKSPACE: the
// event's order id resolves the payment_intents row → workspace →
// that workspace's PayPal config (table first, env fallback). Settlement
// goes through the service-role settle_online_payment RPC (idempotent).
//
// #1638 — approval is not money. The order the event names must be OUR
// intent's order, for the intent's amount, currency and reference, before
// we capture it; the capture is idempotent on PayPal's side
// (`PayPal-Request-Id` fixed per order); a capture that PayPal reports
// COMPLETED settles at once, and an order that is already captured is
// READ BACK rather than captured again. A malformed or foreign amount
// never settles: the RPC is only ever called with the provider's own
// amount, in the intent's currency.

import { env as readEnv, KEYS } from "../_shared/config.ts";
import {
  attachableOrderId,
  captureIdOf,
  isReversalEvent,
  orderIdOf,
  processesEvents,
  reversalReason,
} from "./event_rules.ts";
import { allowsTestPayments } from "../_shared/test_payments.ts";
import {
  configOf,
  redactedProviderLog,
} from "../_shared/webhook_guard.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { paypalApi } from "../_shared/providers.ts";
import { paypalFeeOf } from "../_shared/provider_settlement.ts";
import { approvedOrderMatches, captureApprovedOrder, paypalMatches } from "../_shared/paypal_capture.ts";
import { attachOrder, intentIdOf, provisionalIntent } from "../_shared/provisional_intent.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { guard } from "../_shared/serve.ts";

const FN = "paypal-webhook";

type Intent = {
  id: string;
  order_id: string;
  workspace_id: string;
  amount_cents: number;
  currency: string;
  reference: string;
  status: string;
};
type Money = { value?: string; currency_code?: string } | undefined;

async function paypalConfig(
  admin: SupabaseClient,
  workspaceId: string,
  env: (name: string) => string | undefined,
): Promise<Record<string, string>> {
  const stored = configOf(
    await admin
      .from("payment_credentials")
      .select("config")
      .eq("workspace_id", workspaceId)
      .eq("provider", "paypal")
      .maybeSingle(),
  );
  return {
    client_id: stored.client_id ?? env("PAYPAL_CLIENT_ID") ?? "",
    secret: stored.secret ?? env("PAYPAL_SECRET") ?? "",
    env: stored.env ?? env("PAYPAL_ENV") ?? "sandbox",
    webhook_id: stored.webhook_id ?? env("PAYPAL_WEBHOOK_ID") ?? "",
  };
}

async function accessToken(cfg: Record<string, string>, fetchFn: typeof fetch): Promise<string> {
  const auth = btoa(`${cfg.client_id}:${cfg.secret}`);
  const res = await fetchFn(`${paypalApi(cfg.env)}/v1/oauth2/token`, {
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

/** The amount in [money] is exactly the intent's, in the intent's currency. */
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
      readEnv(KEYS.supabaseUrl)!,
      readEnv(KEYS.supabaseServiceRoleKey)!,
    ),
  env: readEnv,
  fetch: (input, init) => fetch(input, init),
  allowTest: () => allowsTestPayments(),
};

/** #3917 -- the intent an event's resource names by its custom id: a
 * capture carries it, an order carries it on its purchase unit. */
function namedIntent(resource: Record<string, unknown>): string | null {
  const unit = ((resource.purchase_units ?? []) as Array<Record<string, unknown>>)[0];
  return intentIdOf(resource.custom_id ?? unit?.custom_id);
}

export async function handle(req: Request, deps: Deps = defaultDeps): Promise<Response> {
  if (req.method !== "POST") return respond("method_not_allowed", 405);

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(await req.text());
  } catch {
    return respond("invalid_json", 400);
  }

  const admin = deps.admin();
  const resource = (event.resource ?? {}) as Record<string, unknown>;
  // #3905 -- a refund-shaped reversal names its capture (its `up` link), not
  // its order: the payment is found by the capture it recorded.
  const reversalCapture = isReversalEvent(event.event_type) ? captureIdOf(resource) : null;

  // Resolve the workspace from the intent, then load ITS PayPal config.
  const lookupOnce = () => {
    const lookup = admin
      .from("payment_intents")
      .select("id, order_id, workspace_id, amount_cents, currency, reference, status")
      .eq("provider", "paypal");
    return (reversalCapture
      ? lookup.eq("capture_id", reversalCapture)
      : lookup.eq("order_id", orderIdOf(resource))).maybeSingle<Intent>();
  };
  const { data: byOrder, error: lookupError } = await lookupOnce();
  if (lookupError) {
    logLine("error", FN, "intent_lookup_failed");
    return respond("lookup_failed", 500);
  }
  // #3917 -- an intent whose provider answer was uncertain does not know its
  // order yet: the order names it (custom_id), and the order is attached once
  // PayPal has verified the event.
  let intent: Intent | null = byOrder;
  let attach: string | null = null;
  const named = isReversalEvent(event.event_type) ? null : namedIntent(resource);
  if (!intent && named) {
    const provisional = await provisionalIntent<Intent>(
      admin,
      ["paypal"],
      named,
      "id, order_id, workspace_id, amount_cents, currency, reference, status",
    );
    if (provisional.error) {
      logLine("error", FN, "intent_lookup_failed");
      return respond("lookup_failed", 500);
    }
    intent = provisional.data;
    attach = provisional.data?.id ?? null;
    if (!intent) {
      // The order request's own late write may have stored the order between
      // the two reads: read it by the order once more.
      const again = await lookupOnce();
      if (again.error) {
        logLine("error", FN, "intent_lookup_failed");
        return respond("lookup_failed", 500);
      }
      intent = again.data;
    }
  }
  const attachTo = attach ? attachableOrderId(event.event_type, resource) : "";
  if (attach && !attachTo) {
    // A waiting intent the event names, but no order of its own to place it
    // by: PayPal redelivers, and nothing is written meanwhile.
    logLine("error", FN, "no_order_named", { detail: event.event_type });
    return respond("order_unplaced", 500);
  }
  if (!intent) {
    logLine("info", FN, "unknown_order_ignoring", { detail: reversalCapture ?? orderIdOf(resource) });
    return respond("ok", 200);
  }
  let orderId = intent.order_id;
  // #3093 E6 — a failed credential read is an error the provider retries,
  // never a quiet fall back to the installation's key.
  let cfg: Record<string, string>;
  try {
    cfg = await paypalConfig(admin, intent.workspace_id, deps.env);
  } catch (e) {
    logLine("error", FN, "credential_read_failed", { error: describeError(e) });
    return respond("config_unavailable", 500);
  }
  if (!cfg.webhook_id || !cfg.client_id) {
    logLine("info", FN, "not_configured_for_workspace", { detail: intent.workspace_id });
    return respond("not_configured", 200);
  }

  // Verify the transmission against PayPal before trusting anything. An
  // outage of the verifier is NOT a verification: 500, PayPal retries.
  let token: string;
  try {
    token = await accessToken(cfg, deps.fetch);
    const verifyRes = await deps.fetch(
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
    if (!verifyRes.ok) throw new Error(`verify ${verifyRes.status}`);
    const verification = await verifyRes.json();
    if (verification.verification_status !== "SUCCESS") {
      logLine("error", FN, "verification_failed", { status: verification.verification_status });
      return respond("verification_failed", 400);
    }
  } catch (e) {
    logLine("error", FN, "verification_error", { error: describeError(e) });
    return respond("verification_error", 500);
  }
  // #3905 -- a sandbox event settles nothing in a production ledger, unless
  // the installation takes test payments.
  if (!processesEvents(cfg, deps.allowTest())) {
    logLine("info", FN, "test_event_ignored");
    return respond("ok", 200);
  }
  if (attach) {
    const { error, outcome } = await attachOrder(admin, attach, attachTo);
    if (error) {
      logLine("error", FN, "order_attach_failed");
      return respond("attach_failed", 500);
    }
    if (outcome === "other") {
      logLine("info", FN, "intent_holds_another_order");
      return respond("ok", 200);
    }
    orderId = attachTo;
    logLine("info", FN, "order_attached_to_its_intent", { orderId, outcome });
  }

  const settle = async (
    captureId: string,
    amount: Money,
    capture: Record<string, unknown>,
  ): Promise<Response> => {
    if (!paypalMatches(intent, amount)) {
      logLine("error", FN, "capture_does_not_match_the_intent", { orderId,
        amount,
        expected: [intent.amount_cents, intent.currency] });
      return respond("amount_mismatch", 500);
    }
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "paypal",
      p_order_id: orderId,
      p_capture_id: captureId,
      p_amount_cents: intent.amount_cents,
    });
    if (error) {
      logLine("error", FN, "settle_failed", { error: describeError(error) });
      return respond("settle_failed", 500);
    }
    logLine("info", FN, "capture_settled", { orderId, capture: captureId });
    // #2380 — what PayPal kept of it and paid on, recorded once (0687). A
    // capture without its breakdown records nothing; a failed record is
    // retried by PayPal, the settlement above being idempotent.
    const fee = paypalFeeOf(capture);
    if (fee) {
      const recorded = await admin.rpc("record_provider_fee_v1", {
        p_provider: "paypal",
        p_order_id: orderId,
        p_fee_cents: fee.feeCents,
        p_net_cents: fee.netCents,
        p_currency: fee.currency,
        p_transaction_id: fee.transactionId,
      });
      if (recorded.error) {
        logLine("error", FN, "fee_record_failed", { error: describeError(recorded.error) });
        return respond("fee_record_failed", 500);
      }
    }
    return respond("ok", 200);
  };

  const type = event.event_type as string;
  // #3905 -- a capture reversed or refunded at PayPal: recorded on the
  // payment, never posted on its own.
  if (isReversalEvent(type)) {
    const { data: state, error } = await admin.rpc("mark_payment_reversed", {
      p_provider: "paypal",
      p_order_id: orderId,
      p_reason: reversalReason(type, resource),
    });
    if (error) {
      logLine("error", FN, "reversal_record_failed", { error: describeError(error) });
      return respond("reversal_record_failed", 500);
    }
    if (state === "created") {
      // The capture is not recorded yet: PayPal delivers this again.
      logLine("info", FN, "reversal_before_its_capture_retry", { orderId });
      return respond("not_ready", 503);
    }
    logLine("info", FN, "payment_reversed", { orderId, type });
    return respond("ok", 200);
  }
  if (type === "PAYMENT.CAPTURE.COMPLETED") {
    return await settle(String(resource.id), resource.amount as Money, resource);
  }
  if (type === "CHECKOUT.ORDER.APPROVED") {
    // #1555 — approval is the buyer saying yes; it moves no money. An
    // order created with `intent: "CAPTURE"` still has to be captured.
    //
    // #1638 — refuse a foreign or altered order BEFORE any capture: the
    // approved order must carry our reference, amount and currency.
    if (!approvedOrderMatches(intent, resource)) {
      logLine("error", FN, "approved_order_does_not_match_the_intent", { orderId });
      return respond("order_mismatch", 409);
    }
    if (intent.status === "captured") return respond("ok", 200);
    // #4126 -- the one capture, shared with the reconciliation.
    const captured = await captureApprovedOrder(deps.fetch, paypalApi(cfg.env), token, orderId);
    if (captured.kind === "captured") {
      // As before the capture moved here: a settlement that throws after a
      // capture is answered 500, so PayPal redelivers and the capture is read
      // back under its request id.
      try {
        return await settle(captured.id, captured.amount, captured.raw);
      } catch (e) {
        logLine("error", FN, "capture_error", { error: describeError(e) });
        return respond("capture_error", 500);
      }
    }
    if (captured.kind === "pending") {
      // PENDING and friends: the capture exists, the money has not moved;
      // PAYMENT.CAPTURE.COMPLETED settles it later.
      logLine("info", FN, "capture_not_completed_yet", { orderId });
      return respond("ok", 200);
    }
    if (captured.stage === "capture") {
      logLine("error", FN, "capture_failed", { detail: redactedProviderLog(captured.status ?? 0, captured.detail) });
      return respond("capture_failed", 500);
    }
    if (captured.stage === "read") {
      logLine("error", FN, "order_read_failed", { detail: captured.status });
      return respond("order_read_failed", 500);
    }
    logLine("error", FN, "capture_error", { detail: captured.detail });
    return respond("capture_error", 500);
  }
  if (type === "PAYMENT.CAPTURE.DENIED" || type === "CHECKOUT.ORDER.VOIDED") {
    // Only an intent still `created` becomes failed: a captured one keeps
    // its money (mark_payment_failed, 0045).
    await admin.rpc("mark_payment_failed", {
      p_provider: "paypal",
      p_order_id: orderId,
    });
    logLine("info", FN, "payment_marked_failed", { orderId, type });
    return respond("ok", 200);
  }
  logLine("info", FN, "ignored_event", { type });
  return respond("ok", 200);
}

/** The function as it is served: whatever [handle] throws is the envelope (#4412). */
export const serve = (deps: Deps = defaultDeps) => guard(FN, (req) => handle(req, deps));

if (import.meta.main) Deno.serve(serve());
