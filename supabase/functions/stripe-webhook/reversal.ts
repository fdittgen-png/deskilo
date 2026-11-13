// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a payment Stripe reverses (a dispute opened, a refund made at
// Stripe) is recorded on its online payment (`mark_payment_reversed`, 0757): the
// payment becomes `reversed` and a person corrects the ledger.
//
// The event names a charge, not the checkout session, so the workspace is one
// whose OWN webhook secret signed it (as for a payout, payout.ts); the session
// is found from the charge's payment intent with that workspace's key. A
// test-mode event, an event no workspace signed and a charge of no session of
// ours are acknowledged and record nothing.
//
// spec: docs.stripe.com "Events" (`charge.dispute.created`, `charge.refunded`),
// "Dispute object" and "Charge object" (`payment_intent`), "List all Checkout
// Sessions" (`payment_intent` filter) -- field names as documented, not
// verified against a live account.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** The reversal event types recorded. */
const REVERSALS = new Set(["charge.dispute.created", "charge.refunded"]);

export interface ReversalDeps {
  admin: () => SupabaseClient;
  fetch: typeof fetch;
}

type Row = Record<string, unknown>;

/** Whether [type] is a reversal event the books record. */
export const isReversalEvent = (type: unknown): boolean =>
  typeof type === "string" && REVERSALS.has(type);

/** The checkout session of [paymentIntent], read with [key]; null when Stripe
 * has none or refuses the key (4xx but 429, permanent). Throws on a transient
 * failure so Stripe redelivers. */
async function sessionOf(deps: ReversalDeps, key: string, paymentIntent: string): Promise<string | null> {
  const res = await deps.fetch(
    `https://api.stripe.com/v1/checkout/sessions?payment_intent=${encodeURIComponent(paymentIntent)}&limit=1`,
    { headers: { Authorization: `Bearer ${key}` } },
  );
  if (res.status >= 400 && res.status < 500 && res.status !== 429) {
    console.error("stripe reversal: session read refused", { status: res.status });
    return null;
  }
  if (!res.ok) throw new Error(`stripe session read ${res.status}`);
  const body = (await res.json()) as Row;
  const first = ((body.data ?? []) as Row[])[0];
  return typeof first?.id === "string" ? first.id : null;
}

/** Records the reversal of [event]. [verify] says whether a secret signed the
 * event. Answers like the rest of the webhook: 2xx handled or not ours, 5xx
 * retry. */
export async function handleReversal(
  event: Row,
  verify: (secret: string) => Promise<boolean>,
  deps: ReversalDeps,
): Promise<Response> {
  const admin = deps.admin();
  const { data, error } = await admin
    .from("payment_credentials")
    .select("workspace_id, config")
    .eq("provider", "stripe");
  if (error) {
    console.error("stripe reversal: credential lookup failed");
    return new Response("not_ready", { status: 500 });
  }
  let key = "";
  for (const row of (data ?? []) as Array<{ workspace_id: string; config: Row | null }>) {
    const config = (row.config ?? {}) as Record<string, string>;
    if (config.webhook_secret && config.secret_key && (await verify(config.webhook_secret))) {
      key = config.secret_key;
      break;
    }
  }
  if (!key) {
    console.log("stripe reversal: no workspace signed it, ignoring");
    return new Response("ok", { status: 200 });
  }
  if (event.livemode === false) {
    console.log("stripe test event ignored");
    return new Response("ok", { status: 200 });
  }
  const object = ((event.data as Row | undefined)?.object ?? {}) as Row;
  const paymentIntent = typeof object.payment_intent === "string" ? object.payment_intent : "";
  if (!paymentIntent) {
    console.log("stripe reversal: no payment intent, ignoring");
    return new Response("ok", { status: 200 });
  }
  let session: string | null;
  try {
    session = await sessionOf(deps, key, paymentIntent);
  } catch (e) {
    console.error("stripe reversal: session read failed", String(e));
    return new Response("session_read_failed", { status: 500 });
  }
  if (!session) {
    console.log("stripe reversal: no session of ours, ignoring");
    return new Response("ok", { status: 200 });
  }
  const { error: markError } = await admin.rpc("mark_payment_reversed", {
    p_provider: "stripe",
    p_order_id: session,
    p_reason: String(event.type),
  });
  if (markError) {
    console.error("stripe reversal record failed", markError.message);
    return new Response("reversal_record_failed", { status: 500 });
  }
  console.log("stripe payment reversed", session, event.type);
  return new Response("ok", { status: 200 });
}
