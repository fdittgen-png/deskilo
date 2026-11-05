// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 item 4 — what a payment provider reports it kept of a payment and
// paid on: the fee, the net, their currency and the provider's own
// transaction id, read from its payloads. Pure: the webhooks hand the result
// to `record_provider_fee_v1` (0687), which refuses a split that does not add
// up to the payment.
//
//   * PayPal: a completed capture carries `seller_receivable_breakdown`
//     {gross_amount, paypal_fee, net_amount} (Orders v2 / Payments v2);
//   * Stripe: a balance transaction carries `fee` and `net` in minor units
//     of its `currency` (the charge's `balance_transaction`, expanded).
//
// spec: developer.paypal.com "Captures" seller_receivable_breakdown and
// docs.stripe.com "Balance transaction object" — field names as documented,
// not verified against a live account.

import { toMinor } from "./money.ts";

/** A payment's provider settlement facts, in minor units. */
export interface ProviderFee {
  feeCents: number;
  netCents: number;
  currency: string;
  transactionId: string;
}

type Row = Record<string, unknown>;

/** The fee and net of a completed PayPal capture, or null when it carries
 * no complete breakdown (an older capture, a pending one). */
export function paypalFeeOf(capture: Row): ProviderFee | null {
  const breakdown = capture.seller_receivable_breakdown as Row | undefined;
  const id = typeof capture.id === "string" ? capture.id : "";
  if (!breakdown || !id) return null;
  const money = (v: unknown) => {
    const m = (v ?? {}) as Row;
    const currency = String(m.currency_code ?? "").toUpperCase();
    return { currency, cents: toMinor(m.value as string | undefined, currency) };
  };
  const fee = money(breakdown.paypal_fee);
  const net = money(breakdown.net_amount);
  if (fee.cents === null || net.cents === null || !fee.currency || fee.currency !== net.currency) return null;
  return { feeCents: fee.cents, netCents: net.cents, currency: fee.currency, transactionId: id };
}

/** The fee and net of a Stripe balance transaction, or null when it is not
 * one (an id string not expanded, a missing amount). */
export function stripeFeeOf(balanceTransaction: unknown): ProviderFee | null {
  if (typeof balanceTransaction !== "object" || balanceTransaction === null) return null;
  const t = balanceTransaction as Row;
  const id = typeof t.id === "string" ? t.id : "";
  const currency = String(t.currency ?? "").toUpperCase();
  const fee = t.fee, net = t.net;
  if (!id || !currency || !Number.isSafeInteger(fee) || !Number.isSafeInteger(net) || (fee as number) < 0) return null;
  return { feeCents: fee as number, netCents: net as number, currency, transactionId: id };
}
