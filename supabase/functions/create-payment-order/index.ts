// SPDX-License-Identifier: AGPL-3.0-or-later
//
// create-payment-order — starts a REAL online payment for a member's bill
// (docs/design/payments-integration.md). Providers: PayPal (Orders v2),
// Stripe (Checkout), Mollie (Payments) and Wero (through Mollie).
//
// Credentials are PER WORKSPACE, configured from the owner UI and stored in
// the deny-all `payment_credentials` table (read here via the service role);
// deployment-wide env vars are the fallback. A provider whose required
// config is absent is not offered: {action:'config', workspace_id} lists the
// configured providers and, per provider, the missing config fields.
//
// #2595 — this file orchestrates; each responsibility has its module:
//   request.ts   the validated PaymentOrderRequest
//   config.ts    the configuration resolver (and what "configured" means)
//   adapters.ts  provider -> order adapter (stripe.ts, paypal.ts, mollie.ts),
//                each given an injected transport and environment
//   outcome.ts   what an answer means for the stored intent
// Authentication stays here and stays one mode: the caller's verified native
// session. The intent is opened AS that caller; credentials and the order-id
// patch use the privileged client.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import { ORDER_ADAPTERS } from "./adapters.ts";
import { effectiveConfig, missingFields, REQUIRED } from "./config.ts";
import { failureOutcome, idempotencyKey, ProviderRefusal, reuseVerdict } from "./outcome.ts";
import { parsePaymentOrderRequest } from "./request.ts";
import { runtimeDeps } from "./types.ts";
import type { Provider } from "./types.ts";

// The pure pieces stay importable from here (index_test.ts, docs).
export { effectiveConfig, isProvider, missingFields } from "./config.ts";
export {
  failureOutcome,
  idempotencyKey,
  KEY_RETENTION_S,
  ProviderRefusal,
  reuseVerdict,
} from "./outcome.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// ── handler ───────────────────────────────────────────────────────────

export async function handle(req: Request): Promise<Response> {
  // #1553 — the preflight is answered before anything else: it
  // carries no JWT, so any auth or body work would refuse the
  // browser's question instead of answering it.
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  // #1614 — a delegated (MCP) token never opens a payment.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
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

  // AuthN for EVERY action (security audit): the config probe used to
  // answer unauthenticated callers, disclosing which payment providers
  // a workspace has configured. Membership is checked per action below.
  const token = (req.headers.get("Authorization") ?? "").replace(
    "Bearer ",
    "",
  );
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData?.user) {
    console.error("payment auth failed", userError?.message);
    return json({ error: "unauthorized" }, 401);
  }

  // Config probe: which providers can THIS workspace charge with?
  if (body.action === "config") {
    const { data: caller } = await admin
      .from("members")
      .select("id")
      .eq("workspace_id", workspaceId)
      .eq("user_id", userData.user.id)
      .eq("status", "active")
      .maybeSingle();
    if (!caller) return json({ error: "unauthorized" }, 403);
    const providers: Provider[] = [];
    const missing: Record<string, string[]> = {};
    for (const provider of Object.keys(REQUIRED) as Provider[]) {
      let gap: string[];
      try {
        gap = missingFields(
          await effectiveConfig(admin, workspaceId, provider),
          provider,
        );
      } catch {
        // #2014 — unreadable is not offered (fail closed).
        gap = ["config_unavailable"];
      }
      missing[provider] = gap;
      if (gap.length === 0) providers.push(provider);
    }
    console.log("payment config probe", { workspaceId, providers, missing });
    return json({ providers, missing });
  }

  // #917 — a DEVELOPMENT workspace never opens a payment order: the
  // providers below take real money from a real card. Probing the
  // configuration above stays allowed, so a rehearsal space can be set
  // up exactly like the real one; only the charge is refused.
  const { data: ws } = await admin
    .from("workspaces")
    .select("environment, currency_code")
    .eq("id", workspaceId)
    .maybeSingle();
  if ((ws?.environment ?? "dev") !== "prod") {
    return json({
      error: "development_workspace",
      detail:
        "This workspace is a development one: it does not take payments. " +
        "Declare it production to charge for real.",
    }, 409);
  }

  // #1138 — the currency is the WORKSPACE's, never the body's.
  const currency = String(ws?.currency_code ?? "EUR").toUpperCase();
  const parsed = parsePaymentOrderRequest(body, currency);
  if (!parsed.ok) return json(parsed.body, parsed.status);
  const { provider, memberId, amountCents, period, requestId } = parsed.request;

  let cfg: Record<string, string>;
  try {
    cfg = await effectiveConfig(admin, workspaceId, provider);
  } catch {
    // #2014 — no provider call on configuration we could not read.
    console.error("payment config unavailable", { provider });
    return json({ error: "config_unavailable" }, 503);
  }
  const gap = missingFields(cfg, provider);
  if (gap.length > 0) {
    console.log("payment provider not configured", { provider, gap });
    return json({ status: "not_configured", provider, missing: gap });
  }

  // AuthZ: the JWT's user (verified above) must BE the member they pay
  // for.
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

  // #928 — a readable per-workspace reference (PAY-2026-0117) drawn by
  // the number-sequence framework inside the intent's own insert; the
  // provider's order id is patched in once the provider has answered.
  //
  // #1450 — the intent is opened AS THE CALLER. `open_payment_intent`
  // checks `my_active_member` (0210), which reads `auth.uid()`; the
  // service-role client carries no user, so every payment failed with
  // intent_open_failed before reaching a provider. `getUser(token)` above
  // verifies the token; it does not make later calls run as that user.
  // Credentials and the order-id patch stay on the privileged client.
  const caller = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data: opened, error: openError } = await caller.rpc(
    "open_payment_intent",
    {
      p_workspace_id: workspaceId,
      p_member_id: memberId,
      p_provider: provider,
      p_period: period,
      p_amount_cents: amountCents,
      p_currency: currency,
      p_request_id: requestId,
    },
  );
  const intent = Array.isArray(opened) ? opened[0] : opened;
  if (openError || !intent?.reference) {
    console.error("payment intent open failed", openError?.message);
    return json({ error: "intent_open_failed" }, 500);
  }
  const reference: string = intent.reference;
  // #2014 B — a retry of the same request answers from the intent it
  // already opened: paid is paid, failed needs a new request, and a
  // pending one is sent again under the SAME key, so the provider returns
  // the order it already made instead of a second one.
  if (intent.reused) {
    const verdict = reuseVerdict(intent, Date.now());
    if (verdict === "paid") {
      return json({ status: "paid", provider, order_id: intent.order_id });
    }
    if (verdict !== "resend") {
      return json({ error: verdict === "failed" ? "intent_failed" : "intent_stale", provider }, 409);
    }
  }
  const key = idempotencyKey(String(intent.id));
  try {
    const order = await ORDER_ADAPTERS[provider](
      cfg,
      { amountCents, currency, reference, key },
      runtimeDeps(),
    );

    const { error: insertError } = await admin
      .from("payment_intents")
      .update({ order_id: order.orderId })
      .eq("id", intent.id)
      // A reused intent already associated keeps its association.
      .like("order_id", "pending:%");
    if (insertError) {
      console.error("payment intent update failed", insertError.message);
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
    // #2014 — a definitive refusal fails the intent (its number is not
    // reused); a timeout, lost connection or provider 5xx is UNKNOWN: the
    // order may exist, so the intent stays pending for reconciliation and
    // a retry with the same key cannot create a second order. Provider
    // bodies are neither returned nor logged.
    const outcome = failureOutcome(e);
    const status = e instanceof ProviderRefusal ? e.status : null;
    console.error("payment order failed", { provider, outcome, status });
    if (outcome === "failed") {
      await admin.from("payment_intents").update({ status: "failed" }).eq("id", intent.id);
      return json({ error: "provider_error", provider }, 502);
    }
    return json({ error: "outcome_unknown", provider }, 503);
  }
}

if (import.meta.main) Deno.serve(handle);
