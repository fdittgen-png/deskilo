// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- a PayPal reversal names its order as a capture does; only a live
// configuration's events reach a production ledger.
import { assertEquals } from "jsr:@std/assert@1";
import { isReversalEvent, orderIdOf, takesRealMoney } from "./event_rules.ts";

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
