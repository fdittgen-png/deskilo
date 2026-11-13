// SPDX-License-Identifier: AGPL-3.0-or-later
//
// stripe-webhook — verify_jwt OFF; authenticity from the Stripe-Signature
// header (HMAC-SHA256). Credentials are PER WORKSPACE: the session id
// resolves the payment_intents row → workspace → that workspace's Stripe
// webhook secret (table first, env fallback). Settlement is idempotent.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { stripeFeeOf } from "../_shared/provider_settlement.ts";
import { handlePayout, isPayoutEvent } from "./payout.ts";
import { handleReversal, isReversalEvent } from "./reversal.ts";

/** #3093 E5 — the one body of every answer given BEFORE the signature is
 * checked: an unsigned caller learns nothing about which stage refused (the
 * statuses stay, because Stripe's redelivery depends on them). */
const NOT_READY = "not_ready";

// #2014 — a failed credential READ is not an absent credential: it throws
// (the caller answers 500 so Stripe retries) instead of silently falling
// back to the installation's environment secret.
async function webhookSecret(
  admin: SupabaseClient,
  workspaceId: string,
  env: (name: string) => string | undefined,
): Promise<string> {
  const { data, error } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "stripe")
    .maybeSingle();
  if (error) throw new Error("credential lookup failed");
  const stored = (data?.config ?? {}) as Record<string, string>;
  return stored.webhook_secret ?? env("STRIPE_WEBHOOK_SECRET") ?? "";
}

/// #2014 — how long an unknown session is answered with a retry: the
/// provider can call back before the order id is stored on the intent.
/// Older unknown sessions are acknowledged, so an unrelated event on the
/// same Stripe account never retries without end.
export const EARLY_CALLBACK_WINDOW_S = 3600;

export interface Deps {
  admin: () => SupabaseClient;
  env: (name: string) => string | undefined;
  nowS: () => number;
  /** The provider call of the fee read (#2380); injected so a test drives it. */
  fetch?: typeof fetch;
}

const defaultDeps: Deps = {
  admin: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ),
  env: (name) => Deno.env.get(name),
  nowS: () => Date.now() / 1000,
  fetch: (input, init) => fetch(input, init),
};

/** #2380 -- the Stripe API key of a workspace (table first, env fallback),
 * the same lookup order as the webhook secret. */
async function apiKey(
  admin: SupabaseClient,
  workspaceId: string,
  env: (name: string) => string | undefined,
): Promise<string> {
  const { data, error } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "stripe")
    .maybeSingle();
  if (error) throw new Error("credential lookup failed");
  const stored = (data?.config ?? {}) as Record<string, string>;
  return stored.secret_key ?? env("STRIPE_SECRET_KEY") ?? "";
}

/** #2380 -- what Stripe kept of a paid payment: the balance transaction of
 * the payment intent's latest charge, read once with the workspace's own key.
 * Null when Stripe has no balance transaction for it yet (a delayed method
 * reports it later: the settlement events come again) or refuses the key (4xx
 * but 429: permanent, logged). Throws on a transient failure (429, 5xx, the
 * network), so the webhook answers 5xx and Stripe redelivers. */
async function stripeBalanceTransaction(
  deps: Deps,
  key: string,
  paymentIntent: string,
): Promise<unknown> {
  const res = await (deps.fetch ?? fetch)(
    `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntent)}` +
      "?expand[]=latest_charge.balance_transaction",
    { headers: { Authorization: `Bearer ${key}` } },
  );
  // A refusal of the key (403 restricted, 404 a platform key for another
  // account) is permanent: retrying every paid event would end with Stripe
  // disabling this endpoint. It is logged and the fee stays unrecorded; only a
  // transient failure (429, 5xx, the network) is retried.
  if (res.status >= 400 && res.status < 500 && res.status !== 429) {
    console.error("stripe fee unavailable", { status: res.status });
    return null;
  }
  if (!res.ok) throw new Error(`stripe read ${res.status}`);
  const intent = (await res.json()) as Record<string, unknown>;
  const charge = (intent.latest_charge ?? {}) as Record<string, unknown>;
  return charge.balance_transaction ?? null;
}

async function validSignature(
  payload: string,
  header: string,
  secret: string,
  nowS: number,
): Promise<boolean> {
  // #1144 — Stripe sends SEVERAL `v1=` pairs while a webhook secret is
  // being rotated (the old one stays valid up to 24 h), and its reference
  // verifier accepts if ANY matches. `Object.fromEntries` kept only the
  // last, so every payment in the rollover window was charged on the card
  // and never settled.
  const pairs = header.split(",").map((p) => p.split("=") as [string, string]);
  const timestamp = pairs.find(([k]) => k === "t")?.[1];
  const signatures = pairs.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!timestamp || signatures.length === 0) return false;
  if (Math.abs(nowS - Number(timestamp)) > 300) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${timestamp}.${payload}`),
  );
  const expected = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  // Constant-time compare (security audit): `===` short-circuits on the
  // first mismatched byte, leaking a timing side-channel on the one
  // auth-critical comparison in this function.
  // Each candidate compared in constant time; the OR over candidates
  // leaks only how many there were, which the header already says.
  let any = false;
  for (const signature of signatures) {
    if (expected.length !== signature.length) continue;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) {
      diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
    }
    any = any || diff === 0;
  }
  return any;
}

export async function handle(
  req: Request,
  deps: Deps = defaultDeps,
): Promise<Response> {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const payload = await req.text();
  let event: Record<string, unknown>;
  try {
    event = JSON.parse(payload);
  } catch {
    return new Response("invalid_json", { status: 400 });
  }
  const object = ((event.data as Record<string, unknown>)?.object ??
    {}) as Record<string, unknown>;
  const sessionId = String(object.id ?? "");

  // #2380 -- a payout event names no checkout session: the workspace is the
  // one whose own webhook secret signed it (payout.ts).
  if (isPayoutEvent(event.type)) {
    // #3905 -- a test-mode payout reaches no books.
    if (event.livemode === false) {
      console.log("stripe test event ignored");
      return new Response("ok", { status: 200 });
    }
    return await handlePayout(
      event,
      (secret) =>
        validSignature(payload, req.headers.get("stripe-signature") ?? "", secret, deps.nowS()),
      { admin: deps.admin, env: deps.env, fetch: deps.fetch ?? fetch },
    );
  }

  // #3905 -- a dispute or a refund at Stripe names a charge: the workspace is
  // the one whose own webhook secret signed it (reversal.ts).
  if (isReversalEvent(event.type)) {
    return await handleReversal(
      event,
      (secret) =>
        validSignature(payload, req.headers.get("stripe-signature") ?? "", secret, deps.nowS()),
      { admin: deps.admin, env: deps.env, fetch: deps.fetch ?? fetch },
    );
  }

  const admin = deps.admin();
  // #2014 — every answer below is TRUE: 2xx only when the event was
  // handled (or genuinely is not ours); a transient failure is a 5xx so
  // Stripe redelivers it, never a silent "ok".
  const { data: intent, error: lookupError } = await admin
    .from("payment_intents")
    .select("workspace_id")
    .eq("provider", "stripe")
    .eq("order_id", sessionId)
    .maybeSingle();
  if (lookupError) {
    console.error("stripe webhook: intent lookup failed");
    return new Response(NOT_READY, { status: 500 });
  }
  if (!intent) {
    const age = deps.nowS() - Number(event.created ?? 0);
    if (age < EARLY_CALLBACK_WINDOW_S) {
      // The order id may not be stored yet: ask for a redelivery.
      console.log("stripe webhook: session not associated yet, retry");
      return new Response(NOT_READY, { status: 503 });
    }
    console.log("stripe webhook: unknown session, ignoring");
    return new Response("ok", { status: 200 });
  }
  let secret: string;
  try {
    secret = await webhookSecret(admin, intent.workspace_id, deps.env);
  } catch {
    console.error("stripe webhook: credential lookup failed");
    return new Response(NOT_READY, { status: 500 });
  }
  if (!secret) {
    // Not consumed: once the secret is configured, a redelivery settles.
    console.log("stripe webhook not configured for a workspace");
    return new Response(NOT_READY, { status: 503 });
  }
  if (
    !(await validSignature(
      payload,
      req.headers.get("stripe-signature") ?? "",
      secret,
      deps.nowS(),
    ))
  ) {
    console.error("stripe webhook signature verification FAILED");
    return new Response("verification_failed", { status: 400 });
  }
  // #3905 -- a test-mode event settles nothing in a production ledger.
  if (event.livemode === false) {
    console.log("stripe test event ignored");
    return new Response("ok", { status: 200 });
  }

  // #1554 — `completed` means the checkout finished, NOT that the money
  // arrived. A delayed method — SEPA direct debit, Bacs, konbini — ends
  // the session with `payment_status: "unpaid"` and settles days later,
  // or fails. Crediting on `completed` alone posts a ledger entry for
  // money that may never come, and `settle_online_payment` takes no
  // provider status, so nothing underneath catches it.
  //
  // Stripe's own word for "the money is there" is `payment_status`, and
  // for the delayed case it says so afterwards with
  // `async_payment_succeeded` / `async_payment_failed`. Both were being
  // logged and dropped, which is why a SEPA payment that DID arrive was
  // never credited either — the bug cut both ways.
  const paid = object.payment_status === "paid" ||
    object.payment_status === "no_payment_required";
  const settles = (event.type === "checkout.session.completed" && paid) ||
    event.type === "checkout.session.async_payment_succeeded";

  if (event.type === "checkout.session.completed" && !paid) {
    console.log("stripe session completed but not paid — waiting", {
      session: sessionId,
      payment_status: object.payment_status,
    });
  }

  if (settles) {
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "stripe",
      p_order_id: sessionId,
      p_capture_id: String(object.payment_intent ?? sessionId),
      p_amount_cents: object.amount_total ?? null,
    });
    if (error) {
      console.error("stripe settle failed", error.message);
      return new Response("settle_failed", { status: 500 });
    }
    console.log("stripe session settled", { session: sessionId });
    // #2380 -- what Stripe kept of it, recorded once (0687). Settlement above
    // is idempotent, so a failed read or record answers 5xx and Stripe
    // redelivers; a payment Stripe has no balance transaction for yet records
    // nothing now.
    const paymentIntent = String(object.payment_intent ?? "");
    if (paymentIntent) {
      try {
        const key = await apiKey(admin, intent.workspace_id, deps.env);
        if (key) {
          const fee = stripeFeeOf(
            await stripeBalanceTransaction(deps, key, paymentIntent),
          );
          if (fee) {
            const recorded = await admin.rpc("record_provider_fee_v1", {
              p_provider: "stripe",
              p_order_id: sessionId,
              p_fee_cents: fee.feeCents,
              p_net_cents: fee.netCents,
              p_currency: fee.currency,
              p_transaction_id: fee.transactionId,
            });
            if (recorded.error) {
              console.error("stripe fee record failed", recorded.error.message);
              return new Response("fee_record_failed", { status: 500 });
            }
          }
        }
      } catch (e) {
        console.error("stripe fee read failed", String(e));
        return new Response("fee_read_failed", { status: 500 });
      }
    }
  } else if (
    event.type === "checkout.session.expired" ||
    event.type === "checkout.session.async_payment_failed"
  ) {
    const { error } = await admin.rpc("mark_payment_failed", {
      p_provider: "stripe",
      p_order_id: sessionId,
    });
    if (error) {
      console.error("stripe mark failed failed", error.message);
      return new Response("mark_failed_failed", { status: 500 });
    }
    console.log("stripe session marked failed", sessionId, event.type);
  } else {
    console.log("stripe webhook ignored event", event.type);
  }
  return new Response("ok", { status: 200 });
}

if (import.meta.main) Deno.serve((req) => handle(req));
