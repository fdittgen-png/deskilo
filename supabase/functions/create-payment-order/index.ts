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
import { effectiveConfig, missingFields, refusesTestCredentials, REQUIRED } from "./config.ts";
import { allowsTestPayments } from "../_shared/test_payments.ts";
import { failureOutcome, idempotencyKey, ProviderRefusal, reuseVerdict } from "./outcome.ts";
import { parsePaymentOrderRequest } from "./request.ts";
import { continuationOf } from "./continuation.ts";
import { runtimeDeps } from "./types.ts";
import type { Provider } from "./types.ts";

// The pure pieces stay importable from here (index_test.ts, docs).
export { effectiveConfig, isProvider, missingFields } from "./config.ts";
export {
  failureOutcome,
  idempotencyKey,
  ProviderRefusal,
  reuseVerdict,
} from "./outcome.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// ── handler ───────────────────────────────────────────────────────────

export function handle(req: Request): Promise<Response> {
  return handleWith(
    req,
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ),
  );
}

/** A canonical UUID, as `members.id` is. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The request on the service client [admin] (the tests hand in their own). */
export async function handleWith(
  req: Request,
  // deno-lint-ignore no-explicit-any
  admin: any,
  // #3556 — the client that opens the intent as the caller; a test gives
  // its own.
  // deno-lint-ignore no-explicit-any
  callerOf: (token: string) => any = asCaller,
): Promise<Response> {
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
    // #3556 — this function takes a payment's claim of invoices: an app
    // pays a selection only where its host's function says so.
    return json({ providers, missing, claims: true, continuations: true, standalone: true });
  }

  const continued = await continuationOf(body, () => callerOf(token));
  if (continued instanceof Response) return continued;
  if (continued) body = continued;

  // AuthZ first: the JWT's user (verified above) must BE the active member
  // they pay for, in this workspace, before anything about the workspace
  // or its providers is answered.
  const rawMemberId = typeof body.member_id === "string" ? body.member_id : "";
  if (!UUID.test(rawMemberId)) {
    return json({ error: "not_your_bill" }, 403);
  }
  const { data: member } = await admin
    .from("members")
    .select("id, user_id, workspace_id, status")
    .eq("id", rawMemberId)
    .maybeSingle();
  if (
    !member || member.user_id !== userData.user.id ||
    member.workspace_id !== workspaceId || member.status !== "active"
  ) {
    console.error("payment member mismatch", { workspaceId });
    return json({ error: "not_your_bill" }, 403);
  }

  // #917 — a DEVELOPMENT workspace never opens a payment order: the
  // providers below take real money from a real card. Probing the
  // configuration above stays allowed, so a rehearsal space can be set
  // up exactly like the real one; only the charge is refused.
  const { data: ws } = await admin
    .from("workspaces")
    .select("environment, currency_code, name")
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
  const currency = String(continued?.currency ?? ws?.currency_code ?? "EUR").toUpperCase();
  const parsed = parsePaymentOrderRequest(body, currency);
  if (!parsed.ok) return json(parsed.body, parsed.status);
  const { provider, memberId, amountCents, period, requestId, invoiceIds, standalone } = parsed.request;

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
  // #3905 -- a production workspace takes real money only: test credentials
  // open no order, unless the installation takes test payments.
  if (refusesTestCredentials(cfg, provider, allowsTestPayments())) {
    console.log("payment provider holds test credentials", { provider });
    return json({ error: "test_keys", provider }, 409);
  }

  // The order is for the member checked above, whatever the parse read.
  if (memberId !== member.id) return json({ error: "not_your_bill" }, 403);

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
  const caller = callerOf(token);
  // #4165 — a standalone selection is opened by its own adapter, under the
  // explicit allocation mode; the member checked above is its subject.
  const opener = standalone
    ? {
      name: "open_standalone_payment_intent_v1",
      args: {
        p_workspace_id: workspaceId,
        p_financial_subject_id: memberId,
        p_provider: provider,
        p_amount_cents: amountCents,
        p_currency: currency,
        p_request_id: requestId,
        p_invoice_ids: invoiceIds,
      },
    }
    : {
      name: "open_payment_intent",
      args: {
        p_workspace_id: workspaceId,
        p_member_id: memberId,
        p_provider: provider,
        p_period: period,
        p_amount_cents: amountCents,
        p_currency: currency,
        p_request_id: requestId,
        p_invoice_ids: invoiceIds,
      },
    };
  const { data: opened, error: openError } = continued
    ? { data: continued, error: null }
    : await caller.rpc(opener.name, opener.args);
  const intent = Array.isArray(opened) ? opened[0] : opened;
  if (openError || !intent?.reference) {
    const refused = claimRefusal(openError);
    if (refused) return refused;
    console.error("payment intent open failed", openError?.message);
    return json({ error: "intent_open_failed" }, 500);
  }
  const reference: string = intent.reference;
  // #2014 B — a retry of the same request answers from the intent it
  // already opened: paid is paid, failed needs a new request, and a
  // pending one is sent again under the SAME key, so the provider returns
  // the order it already made instead of a second one.
  if (intent.reused) {
    const verdict = reuseVerdict(intent);
    if (verdict === "paid") {
      return json({ status: "paid", provider, order_id: intent.order_id });
    }
    if (verdict !== "resend") {
      return json({ error: verdict === "failed" ? "intent_failed" : "intent_stale", provider }, 409);
    }
  }
  const key = idempotencyKey(String(intent.id));
  try {
    const handed = await handedThen(admin, String(intent.id), provider, () =>
      ORDER_ADAPTERS[provider](
        cfg,
        {
          amountCents,
          currency,
          reference,
          key,
          intentId: String(intent.id),
          payee: String(ws?.name ?? ""),
        },
        runtimeDeps(),
      ));
    if (!handed.ok) return handed.response;
    const order = handed.value;

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
      // #3556 — how many invoices the payment names, so the app can tell
      // its claim was taken.
      claimed: invoiceIds?.length ?? 0,
    });
  } catch (e) {
    return orderFailure(admin, String(intent.id), provider, e, intent.reused === true);
  }
}

/** The client that opens the intent as the caller (#1450). */
function asCaller(token: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

/** #3556 — the database refused the payment's claim of its invoices (an
 * invoice already in another payment, an amount that is not what they
 * still owe, another currency, a withdrawn claim retried, ...): the app
 * answers it by its code (0797's DKC codes), never as a failure of ours.
 * Null for any other error. */
export function claimRefusal(
  error: { code?: string | null } | null | undefined,
): Response | null {
  const code = error?.code ?? "";
  return /^DKC\d{2}$/.test(code) ? json({ error: "claim_refused", code }, 409) : null;
}

/** #3556 — the intent is handed to its provider BEFORE the provider is
 * called, and the database decides it (`hand_payment_intent`), under the
 * claim's locks and by its own clock: from then on the invoices it names
 * wait for the provider's word (or a withdrawal), never for a clock, since
 * the money may arrive whenever the provider settles it. A claim the
 * database finds withdrawn or lapsed is not handed: no provider is called
 * and the app starts a new payment (409 `intent_stale`). A hand-over that
 * cannot be asked calls no provider either (500). A reused intent keeps its
 * first hand-over. */
export async function handedThen<T>(
  // deno-lint-ignore no-explicit-any
  admin: any,
  intentId: string,
  provider: string,
  call: () => Promise<T>,
): Promise<{ ok: true; value: T } | { ok: false; response: Response }> {
  const { data, error } = await admin.rpc("hand_payment_intent", { p_intent: intentId });
  if (error) {
    console.error("payment intent hand-over failed", error.message);
    return { ok: false, response: json({ error: "intent_insert_failed" }, 500) };
  }
  if (data !== true) {
    return { ok: false, response: json({ error: "intent_stale", provider }, 409) };
  }
  return { ok: true, value: await call() };
}

/** #2014 — a definitive refusal fails the intent (its number is not
 * reused); a timeout, lost connection or provider 5xx is UNKNOWN: the
 * order may exist, so the intent stays pending for reconciliation and a
 * retry with the same key cannot create a second order. Provider bodies
 * are neither returned nor logged. */
export async function orderFailure(
  // deno-lint-ignore no-explicit-any
  admin: any,
  intentId: string,
  provider: string,
  e: unknown,
  resent = false,
): Promise<Response> {
  const outcome = failureOutcome(e, resent);
  const status = e instanceof ProviderRefusal ? e.status : null;
  console.error("payment order failed", { provider, outcome, status });
  if (outcome === "failed") {
    // Only an intent still in its first state is marked failed: an intent
    // the provider already settled keeps its status.
    await admin.from("payment_intents").update({ status: "failed" })
      .eq("id", intentId).eq("status", "created");
    return json({ error: "provider_error", provider }, 502);
  }
  return json({ error: "outcome_unknown", provider }, 503);
}

if (import.meta.main) Deno.serve(handle);
