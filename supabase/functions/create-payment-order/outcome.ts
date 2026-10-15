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
 * intent stays pending for reconciliation instead of being declared failed. */
export const failureOutcome = (e: unknown): "failed" | "unknown" =>
  e instanceof ProviderRefusal && e.status >= 400 && e.status < 500
    ? "failed"
    : "unknown";

/** #2014 — one provider order per intent: the same key on every retry. */
export const idempotencyKey = (intentId: string) => `deskilo-intent-${intentId}`;

/** #2014 B — providers keep an idempotency key for about a day. A reused
 * intent older than that is never sent again: the key could have expired
 * and the provider would open a second order. */
export const KEY_RETENTION_S = 23 * 3600;

/** #2014 B — what a REUSED intent allows, from its stored state. */
export function reuseVerdict(
  intent: { status: string; created_at: string },
  nowMs: number,
): "paid" | "failed" | "stale" | "resend" {
  if (intent.status === "captured") return "paid";
  if (intent.status === "failed") return "failed";
  const ageS = (nowMs - Date.parse(intent.created_at)) / 1000;
  return ageS > KEY_RETENTION_S ? "stale" : "resend";
}
