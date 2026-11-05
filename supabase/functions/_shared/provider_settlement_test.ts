// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 item 4 — the provider settlement facts read from fixture payloads in
// the documented shapes: the issue's Stripe fixture (120.00, fee 3.78, net
// 116.22) as a PayPal capture breakdown and as a Stripe balance transaction;
// anything incomplete is no fact.
import { assertEquals } from "jsr:@std/assert@1";
import { paypalFeeOf, stripeFeeOf } from "./provider_settlement.ts";

const capture = {
  id: "2GG279541U471931P",
  status: "COMPLETED",
  amount: { currency_code: "EUR", value: "120.00" },
  seller_receivable_breakdown: {
    gross_amount: { currency_code: "EUR", value: "120.00" },
    paypal_fee: { currency_code: "EUR", value: "3.78" },
    net_amount: { currency_code: "EUR", value: "116.22" },
  },
};

Deno.test("a PayPal capture states its fee and net in its breakdown", () => {
  assertEquals(paypalFeeOf(capture), {
    feeCents: 378,
    netCents: 11622,
    currency: "EUR",
    transactionId: "2GG279541U471931P",
  });
});

Deno.test("a PayPal capture without a complete breakdown states no fee", () => {
  const { seller_receivable_breakdown: _, ...bare } = capture;
  assertEquals(paypalFeeOf(bare), null);
  assertEquals(
    paypalFeeOf({
      ...capture,
      seller_receivable_breakdown: {
        paypal_fee: { currency_code: "USD", value: "3.78" },
        net_amount: { currency_code: "EUR", value: "116.22" },
      },
    }),
    null,
    "a fee and a net in two currencies are not one split",
  );
});

Deno.test("a Stripe balance transaction states its fee and net in minor units", () => {
  assertEquals(
    stripeFeeOf({
      id: "txn_1MiN3gLkdIwHu7ixxapQrznl",
      object: "balance_transaction",
      amount: 12000,
      currency: "eur",
      fee: 378,
      net: 11622,
      type: "charge",
    }),
    { feeCents: 378, netCents: 11622, currency: "EUR", transactionId: "txn_1MiN3gLkdIwHu7ixxapQrznl" },
  );
  // An id not expanded, or a transaction without its fee, is no fact.
  assertEquals(stripeFeeOf("txn_1MiN3gLkdIwHu7ixxapQrznl"), null);
  assertEquals(stripeFeeOf({ id: "txn_1", currency: "eur", net: 11622 }), null);
});
