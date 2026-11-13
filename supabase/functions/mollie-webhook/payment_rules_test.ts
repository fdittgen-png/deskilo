// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a Mollie payment credits a ledger only in live mode, under a live
// key; a paid payment shown charged back or refunded is a reversal.
import { assertEquals } from "jsr:@std/assert@1";
import { type Intent, mismatch, reversalOf } from "./payment_rules.ts";

const intent: Intent = {
  workspace_id: "ws-1",
  provider: "mollie",
  amount_cents: 1200,
  currency: "EUR",
  reference: "PAY-2026-0001",
};

const payment = (over: Record<string, unknown> = {}) => ({
  id: "tr_1",
  status: "paid",
  mode: "live",
  method: "creditcard",
  amount: { value: "12.00", currency: "EUR" },
  metadata: { reference: "PAY-2026-0001" },
  ...over,
});

Deno.test("a live payment under a live key is the intent's", () => {
  assertEquals(mismatch(intent, payment(), "live_abc"), null);
});

Deno.test("a test-mode payment never credits a ledger, whatever the key", () => {
  assertEquals(mismatch(intent, payment({ mode: "test" }), "test_abc"), "mode");
  assertEquals(mismatch(intent, payment({ mode: "test" }), "live_abc"), "mode");
  assertEquals(mismatch(intent, payment(), "test_abc"), "mode");
});

Deno.test("the other checks still hold", () => {
  assertEquals(mismatch(intent, payment({ metadata: { reference: "x" } }), "live_abc"), "reference");
  assertEquals(mismatch(intent, payment({ amount: { value: "11.00", currency: "EUR" } }), "live_abc"), "amount");
});

Deno.test("a charged-back or refunded payment is a reversal; an untouched one is not", () => {
  assertEquals(reversalOf(payment({ amountChargedBack: { value: "12.00", currency: "EUR" } })), "chargeback 12.00 EUR");
  assertEquals(reversalOf(payment({ amountRefunded: { value: "5.00", currency: "EUR" } })), "refund 5.00 EUR");
  assertEquals(reversalOf(payment({ amountRefunded: { value: "0.00", currency: "EUR" } })), null);
  assertEquals(reversalOf(payment()), null);
});

Deno.test("with test payments on, a test-mode payment under a test key is the intent's", () => {
  assertEquals(mismatch(intent, payment({ mode: "test" }), "test_abc", true), null);
  assertEquals(mismatch(intent, payment(), "live_abc", true), null);
  assertEquals(mismatch(intent, payment(), "test_abc", true), "mode");
  assertEquals(mismatch(intent, payment({ mode: "test" }), "live_abc", true), "mode");
});
