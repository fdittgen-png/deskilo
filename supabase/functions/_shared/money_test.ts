// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — the Edge money boundary is exact and mirrors
// accounting_amount.dart: digits in, digits out, no float anywhere; an
// unreviewed currency, excess precision, a malformed string or an amount
// beyond 2^53 − 1 is a refusal, never a rounded or guessed number; the
// wire form carries the minor units as a string and is read back with the
// same checks the app applies.
import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  exponentOf,
  fromWire,
  MAX_SAFE_MINOR,
  minorDigits,
  MoneyRefusal,
  toMajor,
  toMinor,
  toWire,
} from "./money.ts";

Deno.test("the exponent comes from the reviewed tables, never a default", () => {
  assertEquals(exponentOf("EUR"), 2);
  assertEquals(exponentOf("jpy"), 0);
  assertEquals(exponentOf(" KWD "), 3);
  assertEquals(exponentOf("XYZ"), null);
  // The #1137 reader keeps its old answer for an unreviewed code.
  assertEquals(minorDigits("XYZ"), 2);
});

Deno.test("a provider's decimal string becomes minor units exactly", () => {
  assertEquals(toMinor("1149.75", "EUR"), 114975);
  assertEquals(toMinor("120", "EUR"), 12000);
  assertEquals(toMinor("120.5", "EUR"), 12050);
  assertEquals(toMinor("1000", "JPY"), 1000);
  assertEquals(toMinor("12.345", "BHD"), 12345);
  assertEquals(toMinor("-0.01", "EUR"), -1);
  assertEquals(toMinor("0.00", "EUR"), 0);
  // The cases a float gets wrong.
  assertEquals(toMinor("0.29", "EUR"), 29);
  assertEquals(toMinor("1.15", "EUR"), 115);
  assertEquals(toMinor("4.35", "EUR"), 435);
  assertEquals(toMinor("90071992547409.91", "EUR"), 9007199254740991);
});

Deno.test("excess precision, malformed text, unknown currency and overflow are refusals", () => {
  assertEquals(toMinor("19.99", "JPY"), null, "a yen has no minor digits");
  assertEquals(toMinor("1.2345", "BHD"), null, "a dinar has three");
  assertEquals(toMinor("10.001", "EUR"), null);
  for (const bad of ["", " ", "1e3", "12,50", "1 000", "abc", "0x10", "+5", "5.", ".5", "NaN", "Infinity"]) {
    assertEquals(toMinor(bad, "EUR"), null, JSON.stringify(bad));
  }
  assertEquals(toMinor(undefined, "EUR"), null);
  assertEquals(toMinor(null, "EUR"), null);
  assertEquals(toMinor("10.00", "XYZ"), null, "no reviewed exponent: refused, not read as 2");
  assertEquals(toMinor("90071992547409.92", "EUR"), null, "one minor unit past 2^53 − 1");
  assertEquals(toMinor("9007199254740992", "JPY"), null);
});

Deno.test("minor units format from their digits, with the currency's exponent", () => {
  assertEquals(toMajor(114975, "EUR"), "1149.75");
  assertEquals(toMajor(5, "EUR"), "0.05");
  assertEquals(toMajor(0, "EUR"), "0.00");
  assertEquals(toMajor(-1, "EUR"), "-0.01");
  assertEquals(toMajor(1000, "JPY"), "1000");
  assertEquals(toMajor(12345, "BHD"), "12.345");
  assertEquals(toMajor(7, "KWD"), "0.007");
  assertEquals(toMajor(9007199254740991, "EUR"), "90071992547409.91");
  assertEquals(toMajor(9007199254740991n, "JPY"), "9007199254740991");
});

Deno.test("formatting refuses what it cannot represent, by name", () => {
  assertEquals(
    assertThrows(() => toMajor(100, "XYZ"), MoneyRefusal).reason,
    "unsupported_currency",
  );
  assertEquals(assertThrows(() => toMajor(10.5, "EUR"), MoneyRefusal).reason, "not_integer");
  assertEquals(
    assertThrows(() => toMajor(MAX_SAFE_MINOR + 1n, "EUR"), MoneyRefusal).reason,
    "out_of_range",
  );
});

Deno.test("major → minor → major is the identity for every reviewed exponent", () => {
  for (const [major, currency] of [["1149.75", "EUR"], ["1000", "JPY"], ["12.345", "BHD"], ["0.01", "USD"], ["-3.30", "CHF"]]) {
    const minor = toMinor(major, currency);
    assertEquals(minor !== null && toMajor(minor, currency), major);
  }
});

Deno.test("the wire form is the app's: currency, exponent and minor units as a string", () => {
  assertEquals(toWire(114975, "eur"), { currency: "EUR", exponent: 2, minor: "114975" });
  assertEquals(toWire(-1000, "JPY"), { currency: "JPY", exponent: 0, minor: "-1000" });
  assertEquals(toWire(9007199254740991n, "BHD").minor, "9007199254740991");
  assertEquals(
    assertThrows(() => toWire(1, "XYZ"), MoneyRefusal).reason,
    "unsupported_currency",
  );
  assertEquals(fromWire({ currency: "EUR", exponent: 2, minor: "114975" }), {
    currency: "EUR",
    exponent: 2,
    minor: 114975,
  });
  assertEquals(fromWire(toWire(12345, "BHD")), { currency: "BHD", exponent: 3, minor: 12345 });
});

Deno.test("reading the wire form refuses a wrong exponent, a number, a float or an overflow", () => {
  assertEquals(fromWire({ currency: "EUR", exponent: 0, minor: "100" }), null, "the exponent must be the currency's");
  assertEquals(fromWire({ currency: "EUR", exponent: 2, minor: 100 }), null, "minor units travel as a string");
  assertEquals(fromWire({ currency: "EUR", exponent: 2, minor: "100.5" }), null);
  assertEquals(fromWire({ currency: "EUR", exponent: 2, minor: "9007199254740992" }), null);
  assertEquals(fromWire({ currency: "XYZ", exponent: 2, minor: "100" }), null);
  assertEquals(fromWire({ exponent: 2, minor: "100" }), null);
  assertEquals(fromWire(null), null);
  assertEquals(fromWire("114975 EUR"), null);
});
