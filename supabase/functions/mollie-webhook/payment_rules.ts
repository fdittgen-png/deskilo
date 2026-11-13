// SPDX-License-Identifier: AGPL-3.0-or-later
//
// mollie-webhook's rules on a fetched payment, apart from the server so they
// can be tested.
//
// #1639 -- the fetched payment must be the intent's: its metadata reference,
// its currency and amount, the method the intent was opened for (a Wero intent
// settles only a Wero payment). #3905 -- and a live payment under a live key:
// a test-mode payment never credits a ledger.
//
// #3905 -- a paid payment Mollie shows charged back or refunded is reversed:
// recorded on its online payment, never settled.

import { toMinor } from "../_shared/money.ts";
import { mollieKeyMode } from "../_shared/providers.ts";

export type Intent = {
  workspace_id: string;
  provider: string;
  amount_cents: number;
  currency: string;
  reference: string;
};

/** Why the fetched [payment] is not the intent's, or null when it is. */
export function mismatch(
  intent: Intent,
  payment: Record<string, unknown>,
  key: string,
): string | null {
  const metadata = (payment.metadata ?? {}) as Record<string, unknown>;
  if (metadata.reference !== intent.reference) return "reference";
  const amount = (payment.amount ?? {}) as Record<string, unknown>;
  const currency = String(amount.currency ?? "").toUpperCase();
  if (currency !== intent.currency.toUpperCase()) return "currency";
  const cents = toMinor(amount.value as string | undefined, currency);
  if (cents === null || cents !== intent.amount_cents) return "amount";
  if (intent.provider === "wero" && payment.method !== "wero") return "method";
  if (mollieKeyMode(key) !== "live" || payment.mode !== "live") return "mode";
  return null;
}

/** The reversal a fetched [payment] shows (`chargeback` before `refund`), or
 * null when nothing of it was charged back or refunded. */
export function reversalOf(payment: Record<string, unknown>): string | null {
  const above = (field: string) => {
    const value = Number(((payment[field] ?? {}) as Record<string, unknown>).value ?? 0);
    return Number.isFinite(value) && value > 0;
  };
  if (above("amountChargedBack")) return "chargeback";
  if (above("amountRefunded")) return "refund";
  return null;
}
