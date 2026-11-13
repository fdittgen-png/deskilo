// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a PayPal reversal names its order as a capture does; only a live
// configuration's events reach a production ledger.
import { assertEquals } from "jsr:@std/assert@1";
import { captureIdOf, isReversalEvent, orderIdOf, reversalReason, takesRealMoney } from "./event_rules.ts";

Deno.test("a reversed or refunded capture names its order", () => {
  const capture = { id: "cap_1", supplementary_data: { related_ids: { order_id: "ORDER-1" } } };
  assertEquals(orderIdOf(capture), "ORDER-1");
  assertEquals(orderIdOf({ id: "ORDER-2" }), "ORDER-2");
  assertEquals(orderIdOf({}), "");
});

Deno.test("the events that reverse a payment", () => {
  for (const t of ["PAYMENT.CAPTURE.REVERSED", "PAYMENT.CAPTURE.REFUNDED"]) assertEquals(isReversalEvent(t), true);
  for (const t of ["PAYMENT.CAPTURE.COMPLETED", "PAYMENT.CAPTURE.DENIED", "CHECKOUT.ORDER.APPROVED", undefined]) {
    assertEquals(isReversalEvent(t), false);
  }
});

Deno.test("only a live configuration takes real money", () => {
  assertEquals(takesRealMoney({ env: "live" }), true);
  assertEquals(takesRealMoney({ env: "sandbox" }), false);
  assertEquals(takesRealMoney({}), false);
});

// A refund-shaped resource, as PAYMENT.CAPTURE.REFUNDED carries it: its own
// `self` link and an `up` link to the capture it refunds.
const refund = {
  id: "REFUND-1",
  status: "COMPLETED",
  amount: { value: "5.00", currency_code: "EUR" },
  links: [
    { href: "https://api.paypal.com/v2/payments/refunds/REFUND-1", rel: "self", method: "GET" },
    { href: "https://api.paypal.com/v2/payments/captures/CAPTURE-9", rel: "up", method: "GET" },
  ],
};

Deno.test("a refund names the capture it refunds, and the reason its amount", () => {
  assertEquals(captureIdOf(refund), "CAPTURE-9");
  assertEquals(captureIdOf({ links: [{ href: "https://api.paypal.com/v2/checkout/orders/O-1", rel: "up" }] }), null);
  assertEquals(captureIdOf({}), null);
  assertEquals(reversalReason("PAYMENT.CAPTURE.REFUNDED", refund), "PAYMENT.CAPTURE.REFUNDED 5.00 EUR");
  assertEquals(reversalReason("PAYMENT.CAPTURE.REVERSED", {}), "PAYMENT.CAPTURE.REVERSED");
});
