// SPDX-License-Identifier: AGPL-3.0-or-later
//
// paypal-webhook's rules on an event, apart from the server so they can be
// tested: which order an event names, which events reverse a payment, and
// which configuration takes real money.

/** The order an event names: the capture's (or refund's) related order, else
 * the resource itself (an order event). */
export function orderIdOf(resource: Record<string, unknown>): string {
  return String(
    ((resource.supplementary_data as Record<string, unknown> | undefined)
      ?.related_ids as Record<string, unknown> | undefined)?.order_id ??
      resource.id ?? "",
  );
}

/** #3905 -- the capture a refund-shaped resource belongs to: its `up` link
 * (`…/v2/payments/captures/<id>`); null when the resource names none. */
export function captureIdOf(resource: Record<string, unknown>): string | null {
  for (const link of (resource.links ?? []) as Array<Record<string, unknown>>) {
    const match = /\/v2\/payments\/captures\/([^/?#]+)/.exec(String(link.href ?? ""));
    if (link.rel === "up" && match) return decodeURIComponent(match[1]);
  }
  return null;
}

/** #3905 -- why a reversal event reverses its payment, with the amount and
 * its currency. */
export function reversalReason(type: string, resource: Record<string, unknown>): string {
  const amount = (resource.amount ?? {}) as Record<string, unknown>;
  return [type, amount.value, amount.currency_code].filter((p) => typeof p === "string" && p).join(" ");
}

/** #3905 -- the events that reverse a captured payment. */
const REVERSALS = new Set(["PAYMENT.CAPTURE.REVERSED", "PAYMENT.CAPTURE.REFUNDED"]);

export const isReversalEvent = (type: unknown): boolean =>
  typeof type === "string" && REVERSALS.has(type);

/** #3905 -- only a live configuration's events reach a production ledger. */
export const takesRealMoney = (cfg: Record<string, string>): boolean => cfg.env === "live";
