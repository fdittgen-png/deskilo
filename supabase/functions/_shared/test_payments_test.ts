// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- test payments are on only when the operator sets the switch to
// "true" in the functions' environment.
import { assertEquals } from "jsr:@std/assert@1";
import { allowsTestPayments } from "./test_payments.ts";

Deno.test("test payments are on only with the switch set to true", () => {
  const env = (value?: string) => (name: string) =>
    name === "DESKILO_ALLOW_TEST_PAYMENTS" ? value : undefined;
  assertEquals(allowsTestPayments(env("true")), true);
  assertEquals(allowsTestPayments(env()), false);
  assertEquals(allowsTestPayments(env("false")), false);
  assertEquals(allowsTestPayments(env("1")), false);
});
