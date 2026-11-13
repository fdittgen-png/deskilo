// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3905 -- the test credentials of each provider are recognised by their
// shape, so a production workspace opens no order on them.
import { assertEquals } from "jsr:@std/assert@1";
import { usesTestCredentials } from "./config.ts";

Deno.test("a Stripe test key is a test credential; a live key is not", () => {
  assertEquals(usesTestCredentials({ secret_key: "sk_test_abc" }, "stripe"), true);
  assertEquals(usesTestCredentials({ secret_key: "rk_test_abc" }, "stripe"), true);
  assertEquals(usesTestCredentials({ secret_key: "sk_live_abc" }, "stripe"), false);
  assertEquals(usesTestCredentials({ secret_key: "rk_live_abc" }, "stripe"), false);
});

Deno.test("a Mollie test key is a test credential, for Wero too", () => {
  assertEquals(usesTestCredentials({ api_key: "test_abc" }, "mollie"), true);
  assertEquals(usesTestCredentials({ api_key: "live_abc" }, "mollie"), false);
  assertEquals(usesTestCredentials({ api_key: "test_abc" }, "wero"), true);
  assertEquals(usesTestCredentials({ api_key: "live_abc" }, "wero"), false);
});

Deno.test("a PayPal configuration outside live is a test credential", () => {
  assertEquals(usesTestCredentials({ env: "sandbox" }, "paypal"), true);
  assertEquals(usesTestCredentials({}, "paypal"), true);
  assertEquals(usesTestCredentials({ env: "live" }, "paypal"), false);
});
