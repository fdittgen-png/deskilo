// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3093 — the small guards the payment webhooks and the VAT check share, pure
// so each is testable: a credential read that fails is an error, never a quiet
// fall back to the installation's key; a provider's transmission time must be
// recent; a provider's body is never logged whole; a database error never
// travels to the caller.

/** The most a webhook's own timestamp may be off the clock. */
export const MAX_TRANSMISSION_SKEW_MS = 5 * 60 * 1000;

/** Whether the provider's transmission [time] (an ISO timestamp) is within
 * [skewMs] of [now]; a missing or unreadable time is not fresh. */
export function transmissionFresh(
  time: string | null | undefined,
  now: number,
  skewMs: number = MAX_TRANSMISSION_SKEW_MS,
): boolean {
  if (!time) return false;
  const at = Date.parse(time);
  return Number.isFinite(at) && Math.abs(now - at) <= skewMs;
}

/** The stored credential config of a read, or an error when the read
 * failed: the caller answers 500 (the provider retries) instead of using
 * the installation's own key for a workspace that has its own. */
export function configOf(
  read: { data: { config?: unknown } | null; error: unknown },
): Record<string, string> {
  if (read.error) throw new Error("credential read failed");
  return (read.data?.config ?? {}) as Record<string, string>;
}

/** What may be logged of a provider's answer: its status and its debug id,
 * never the body, which can hold the payer's data. */
export function redactedProviderLog(
  status: number,
  body: string,
): { status: number; debug_id?: string } {
  try {
    const parsed = JSON.parse(body);
    const id = parsed?.debug_id;
    return typeof id === "string" ? { status, debug_id: id } : { status };
  } catch {
    return { status };
  }
}

/** The one code a caller sees for any database refusal: the text of a
 * Postgres error names tables, columns and constraints. */
export const REFUSED_CODE = "refused";
