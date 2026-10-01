// SPDX-License-Identifier: AGPL-3.0-or-later
//
// stripe-webhook — verify_jwt OFF; authenticity from the Stripe-Signature
// header (HMAC-SHA256). Credentials are PER WORKSPACE: the session id
// resolves the payment_intents row → workspace → that workspace's Stripe
// webhook secret (table first, env fallback). Settlement is idempotent.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

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
}

const defaultDeps: Deps = {
  admin: () =>
    createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    ),
  env: (name) => Deno.env.get(name),
  nowS: () => Date.now() / 1000,
};

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
    return new Response("lookup_failed", { status: 500 });
  }
  if (!intent) {
    const age = deps.nowS() - Number(event.created ?? 0);
    if (age < EARLY_CALLBACK_WINDOW_S) {
      // The order id may not be stored yet: ask for a redelivery.
      console.log("stripe webhook: session not associated yet, retry", sessionId);
      return new Response("not_associated_yet", { status: 503 });
    }
    console.log("stripe webhook: unknown session, ignoring", sessionId);
    return new Response("ok", { status: 200 });
  }
  let secret: string;
  try {
    secret = await webhookSecret(admin, intent.workspace_id, deps.env);
  } catch {
    console.error("stripe webhook: credential lookup failed");
    return new Response("lookup_failed", { status: 500 });
  }
  if (!secret) {
    // Not consumed: once the secret is configured, a redelivery settles.
    console.log("stripe webhook not configured for workspace", intent.workspace_id);
    return new Response("not_configured", { status: 503 });
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
