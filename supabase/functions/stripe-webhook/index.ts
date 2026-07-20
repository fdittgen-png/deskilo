// SPDX-License-Identifier: MIT
//
// stripe-webhook — Stripe calls this on checkout events. Deployed with
// verify_jwt OFF; authenticity comes from the Stripe-Signature header
// (HMAC-SHA256 over `${t}.${payload}` with STRIPE_WEBHOOK_SECRET). On
// checkout.session.completed the session settles through the service-role
// settle_online_payment RPC (idempotent per order).

import { createClient } from "npm:@supabase/supabase-js@2";

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
  // Reject stale events (replay protection, 5 min).
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

  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!secret) {
    console.log("stripe webhook not configured — ignoring event");
    return new Response("not_configured", { status: 200 });
  }

  const payload = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  if (!(await validSignature(payload, signature, secret))) {
    console.error("stripe webhook signature verification FAILED");
    return new Response("verification_failed", { status: 400 });
  }

  const event = JSON.parse(payload);
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const { error } = await admin.rpc("settle_online_payment", {
      p_provider: "stripe",
      p_order_id: String(session.id),
      p_capture_id: String(session.payment_intent ?? session.id),
      p_amount_cents: session.amount_total ?? null,
    });
    if (error) {
      console.error("stripe settle failed", error.message);
      return new Response("settle_failed", { status: 500 });
    }
    console.log("stripe session settled", { session: session.id });
  } else if (event.type === "checkout.session.expired") {
    await admin.rpc("mark_payment_failed", {
      p_provider: "stripe",
      p_order_id: String(event.data.object.id),
    });
    console.log("stripe session marked failed", event.data.object.id);
  } else {
    console.log("stripe webhook ignored event", event.type);
  }
  return new Response("ok", { status: 200 });
});
