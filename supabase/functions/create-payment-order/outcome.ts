// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2014 / #2595 — what a provider's answer means for the stored intent,
// and what a REUSED intent allows. Pure: no network, no database, and the
// clock is an argument.

/** #2014 — the provider ANSWERED and refused (HTTP status kept, body not). */
export class ProviderRefusal extends Error {
  constructor(readonly status: number) {
    super(`provider refused: HTTP ${status}`);
  }
}

/** #2014 — `failed` only for a definitive refusal (4xx); a timeout, a lost
 * connection or a provider 5xx is UNKNOWN: the order may exist, so the
 * intent stays pending for reconciliation instead of being declared failed.
 * A 4xx that asks to wait or repeat (408 timeout, 409 conflict, 425 too
 * early, 429 too many requests) is not definitive either. */
const NOT_DEFINITIVE = [408, 409, 425, 429];

/** #3917 -- a [resent] intent's order may already exist under its key: a
 * 400 to it is the provider refusing parameters that differ from the first
 * request under that key (Stripe's idempotency_error, Mollie's 400 Bad
 * Request for a reused key), never a refusal of the order. */
export const failureOutcome = (e: unknown, resent = false): "failed" | "unknown" =>
  e instanceof ProviderRefusal && e.status >= 400 && e.status < 500 &&
    !NOT_DEFINITIVE.includes(e.status) && !(resent && e.status === 400)
    ? "failed"
    : "unknown";

/** #2014 — one provider order per intent: the same key on every retry. */
export const idempotencyKey = (intentId: string) => `deskilo-intent-${intentId}`;

/** #2014 B — what a REUSED intent allows, from its stored state. How long a
 * provider honours a request's key is the database's to say (#4217: a
 * platform setting per provider, counted from the hand-over): the hand-over
 * refuses a checkout outside it and the intent is then answered as stale. */
export function reuseVerdict(
  intent: { status: string },
): "paid" | "failed" | "resend" {
  if (intent.status === "captured") return "paid";
  if (intent.status === "failed") return "failed";
  return "resend";
}
