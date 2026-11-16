// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a PayPal reversal names its order as a capture does; only a live
// configuration's events reach a production ledger.
import { assertEquals } from "jsr:@std/assert@1";
import {
  attachableOrderId,
  captureIdOf,
  isReversalEvent,
  orderIdOf,
  processesEvents,
  reversalReason,
  takesRealMoney,
} from "./event_rules.ts";

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

Deno.test("a sandbox configuration's events are processed only with test payments on", () => {
  assertEquals(processesEvents({ env: "sandbox" }, false), false);
  assertEquals(processesEvents({ env: "sandbox" }, true), true);
  assertEquals(processesEvents({ env: "live" }, false), true);
});

Deno.test("#3917: the order an event may attach is never a capture's or a refund's id", () => {
  const related = { supplementary_data: { related_ids: { order_id: "O-1" } } };
  assertEquals(attachableOrderId("CHECKOUT.ORDER.APPROVED", { id: "O-1" }), "O-1");
  assertEquals(attachableOrderId("PAYMENT.CAPTURE.COMPLETED", { id: "CAP-1", ...related }), "O-1");
  assertEquals(attachableOrderId("PAYMENT.CAPTURE.COMPLETED", { id: "CAP-1" }), "");
  assertEquals(attachableOrderId("PAYMENT.CAPTURE.REFUNDED", { id: "REF-1", ...related }), "");
  assertEquals(attachableOrderId("PAYMENT.CAPTURE.REVERSED", { id: "REV-1", ...related }), "");
  assertEquals(attachableOrderId("CHECKOUT.ORDER.APPROVED", {}), "");
});
