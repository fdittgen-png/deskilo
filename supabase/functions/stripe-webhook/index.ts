// SPDX-License-Identifier: 0BSD
//
// stripe-webhook — verify_jwt OFF; authenticity from the Stripe-Signature
// header (HMAC-SHA256). Credentials are PER WORKSPACE: the session id
// resolves the payment_intents row → workspace → that workspace's Stripe
// webhook secret (table first, env fallback). Settlement is idempotent.

import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

async function webhookSecret(
  admin: SupabaseClient,
  workspaceId: string,
): Promise<string> {
  const { data } = await admin
    .from("payment_credentials")
    .select("config")
    .eq("workspace_id", workspaceId)
    .eq("provider", "stripe")
    .maybeSingle();
  const stored = (data?.config ?? {}) as Record<string, string>;
  return stored.webhook_secret ?? Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
}

async function validSignature(
  payload: string,
  header: string,
  secret: string,
): Promise<boolean> {
  const parts = Object.fromEntries(
    header.split(",").map((p) => p.split("=") as [string, string]),
  );
  const timestamp = parts["t"];
  const signature = parts["v1"];
  if (!timestamp || !signature) return false;
  if (Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) return false;
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
  return expected === signature;
}

Deno.serve(async (req: Request): Promise<Response> => {
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

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: intent } = await admin
    .from("payment_intents")
    .select("workspace_id")
    .eq("provider", "stripe")
    .eq("order_id", sessionId)
    .maybeSingle();
  if (!intent) {
    console.log("stripe webhook: unknown session, ignoring", sessionId);
    return new Response("ok", { status: 200 });
  }
  const secret = await webhookSecret(admin, intent.workspace_id);
  if (!secret) {
    console.log("stripe webhook not configured for workspace", intent.workspace_id);
    return new Response("not_configured", { status: 200 });
  }
  if (
    !(await validSignature(
      payload,
      req.headers.get("stripe-signature") ?? "",
      secret,
    ))
  ) {
    console.error("stripe webhook signature verification FAILED");
    return new Response("verification_failed", { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
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
  } else if (event.type === "checkout.session.expired") {
    await admin.rpc("mark_payment_failed", {
      p_provider: "stripe",
      p_order_id: sessionId,
    });
    console.log("stripe session marked failed", sessionId);
  } else {
    console.log("stripe webhook ignored event", event.type);
  }
  return new Response("ok", { status: 200 });
});
