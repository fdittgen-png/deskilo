// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a payment Stripe reverses (a dispute opened, a refund made at
// Stripe) is recorded on its online payment (`mark_payment_reversed`, 0757): the
// payment becomes `reversed`, its reason names the amount reversed, and a person
// corrects the ledger.
//
// The event names a charge, not the checkout session, so the session is found
// from the charge's payment intent with the key of a workspace whose OWN
// webhook secret signed the event (as for a payout, payout.ts). Every such
// workspace is tried in turn (two may share one Stripe account), then the
// installation's own secret and key. A key Stripe refuses or a transient
// failure asks Stripe to deliver again (5xx), and so does a reversal of a
// payment whose capture has not been recorded yet; only "no such session"
// is acknowledged and recorded as nothing. A test-mode event records nothing.
//
// spec: docs.stripe.com "Events" (`charge.dispute.created`, `charge.refunded`),
// "Dispute object" (`amount`, `currency`, `payment_intent`), "Charge object"
// (`amount_refunded`, `currency`, `payment_intent`), "List all Checkout
// Sessions" (`payment_intent` filter) -- field names as documented, not
// verified against a live account.
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { toMajor } from "../_shared/money.ts";

/** The reversal event types recorded, with the field naming the amount. */
const REVERSALS: Record<string, string> = {
  "charge.dispute.created": "amount",
  "charge.refunded": "amount_refunded",
};

export interface ReversalDeps {
  admin: () => SupabaseClient;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
}

type Row = Record<string, unknown>;

/** Whether [type] is a reversal event the books record. */
export const isReversalEvent = (type: unknown): boolean =>
  typeof type === "string" && Object.hasOwn(REVERSALS, type);

/** Why [event] reverses its payment, with the amount and its currency. */
export function reversalReason(event: Row): string {
  const type = String(event.type);
  const object = ((event.data as Row | undefined)?.object ?? {}) as Row;
  const currency = String(object.currency ?? "").toUpperCase();
  const minor = object[REVERSALS[type] ?? ""];
  if (!currency || typeof minor !== "number" || !Number.isSafeInteger(minor)) return type;
  try {
    return `${type} ${toMajor(minor, currency)} ${currency}`;
  } catch {
    return `${type} ${minor} ${currency}`;
  }
}

/** A key Stripe refused: permanent for this key, never "no such session". */
class KeyRefused extends Error {}

/** The checkout session of [paymentIntent], read with [key]; null when Stripe
 * has none. Throws [KeyRefused] on a refused key and an Error on a transient
 * failure. */
async function sessionOf(deps: ReversalDeps, key: string, paymentIntent: string): Promise<string | null> {
  const res = await deps.fetch(
    `https://api.stripe.com/v1/checkout/sessions?payment_intent=${encodeURIComponent(paymentIntent)}&limit=1`,
    { headers: { Authorization: `Bearer ${key}` } },
  );
  if (res.status === 404) return null;
  if (res.status === 401 || res.status === 403) throw new KeyRefused(`stripe session read ${res.status}`);
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
  // Every key whose secret signed the event, the installation's own last.
  const keys: string[] = [];
  const candidates = [
    ...((data ?? []) as Array<{ config: Row | null }>).map((row) => (row.config ?? {}) as Record<string, string>),
    { webhook_secret: deps.env("STRIPE_WEBHOOK_SECRET") ?? "", secret_key: deps.env("STRIPE_SECRET_KEY") ?? "" },
  ];
  for (const config of candidates) {
    if (config.webhook_secret && config.secret_key && (await verify(config.webhook_secret))) {
      if (!keys.includes(config.secret_key)) keys.push(config.secret_key);
    }
  }
  if (keys.length === 0) {
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
  let session: string | null = null;
  let unread = false;
  for (const key of keys) {
    try {
      session = await sessionOf(deps, key, paymentIntent);
    } catch (e) {
      console.error("stripe reversal: session read failed", String(e));
      unread = true;
      continue;
    }
    if (session) break;
  }
  if (!session) {
    if (unread) return new Response("session_read_failed", { status: 500 });
    console.log("stripe reversal: no session of ours, ignoring");
    return new Response("ok", { status: 200 });
  }
  const { data: state, error: markError } = await admin.rpc("mark_payment_reversed", {
    p_provider: "stripe",
    p_order_id: session,
    p_reason: reversalReason(event),
  });
  if (markError) {
    console.error("stripe reversal record failed", markError.message);
    return new Response("reversal_record_failed", { status: 500 });
  }
  if (state === "created") {
    // The capture is not recorded yet: Stripe delivers this again.
    console.log("stripe reversal before its capture, retry", session);
    return new Response("not_ready", { status: 503 });
  }
  console.log("stripe payment reversed", session, event.type);
  return new Response("ok", { status: 200 });
}
