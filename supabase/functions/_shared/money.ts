// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1137 — ONE conversion between a provider's major-unit decimal string
// and the app's minor units, shared by the order and the webhooks.
//
// `create-payment-order` already knew that a yen has no minor digits
// (#711) and sent Mollie and PayPal the right major-unit string. The
// webhooks, written earlier, still did `parseFloat(v) * 100` on the way
// back — so a ¥1000 payment came back as 100 000 minor units and was
// credited a hundred times over. Two copies of one rule disagreed within
// a release, which is what a shared module is for.
//
// #1870 — and the rule is exact. This is the Edge side of
// lib/features/money/domain/accounting_amount.dart: the same reviewed
// currency tables (a code outside them is refused, never read as two
// decimals), the same range (±(2^53 − 1) minor units, what a JSON number
// carries exactly), the same wire form (`{currency, exponent, minor}` with
// the minor units as a STRING of digits). No binary floating-point number
// touches an amount: a decimal string is split into digits and scaled with
// BigInt; a major-unit string is formatted from the integer's digits.
// test/lint/money_wire_parity_test.dart pins the tables and keys below to
// the Dart ones.

/** Codes with NO minor unit — Currencies.zeroDecimal. */
const ZERO_DECIMAL = new Set([
  "BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","VND","VUV","XAF","XOF","XPF",
]);
/** Codes with THREE minor digits — Currencies.threeDecimal. */
const THREE_DECIMAL = new Set(["BHD","IQD","JOD","KWD","LYD","OMR","TND"]);
/** The two-decimal codes an owner may pick — Currencies.selectable (the
 * zero-decimal ones among them are listed above). */
const TWO_DECIMAL = new Set([
  "AUD","BGN","BRL","CAD","CHF","CNY","CZK","DKK","EUR","GBP",
  "HKD","HRK","HUF","ILS","INR","MXN","NOK",
  "NZD","PLN","RON","SEK","SGD","TRY","USD","ZAR",
]);

/** The largest magnitude that survives JSON (an IEEE double) exactly —
 * accounting_amount.dart `maxSafeMinor`. */
export const MAX_SAFE_MINOR = 9007199254740991n;

/** The minor-unit exponent of [currency], or null when the code has no
 * reviewed exponent. Never assumed to be 2. */
export const exponentOf = (currency: string): number | null => {
  const code = currency.trim().toUpperCase();
  if (ZERO_DECIMAL.has(code)) return 0;
  if (THREE_DECIMAL.has(code)) return 3;
  if (TWO_DECIMAL.has(code)) return 2;
  return null;
};

/** Kept for readers of #1137: the exponent, or 2 for an unreviewed code.
 * New code asks `exponentOf` and treats null as a refusal. */
export const minorDigits = (currency: string): number => exponentOf(currency) ?? 2;

export type MoneyRefusalReason = "unsupported_currency" | "out_of_range" | "not_integer";

/** A typed refusal: the caller blocks the one document, nothing is
 * guessed. */
export class MoneyRefusal extends Error {
  constructor(readonly reason: MoneyRefusalReason, detail: string) {
    super(`${reason}: ${detail}`);
    this.name = "MoneyRefusal";
  }
}

const inRange = (minor: bigint): boolean =>
  (minor < 0n ? -minor : minor) <= MAX_SAFE_MINOR;

const asInteger = (minor: number | bigint, code: string): bigint => {
  if (typeof minor === "number" && !Number.isInteger(minor)) {
    throw new MoneyRefusal("not_integer", `${minor} ${code}`);
  }
  const v = BigInt(minor);
  if (!inRange(v)) throw new MoneyRefusal("out_of_range", `${v} ${code}`);
  return v;
};

/** Minor units → the provider's major-unit decimal string ("10.00",
 * "1000", "12.345"), from the integer's digits. Refuses (throws) an
 * unreviewed currency, a non-integer or an out-of-range value. */
export const toMajor = (minor: number | bigint, currency: string): string => {
  const exponent = exponentOf(currency);
  if (exponent === null) throw new MoneyRefusal("unsupported_currency", currency);
  const v = asInteger(minor, currency);
  const sign = v < 0n ? "-" : "";
  const digits = (v < 0n ? -v : v).toString().padStart(exponent + 1, "0");
  if (exponent === 0) return `${sign}${digits}`;
  return `${sign}${digits.slice(0, -exponent)}.${digits.slice(-exponent)}`;
};

/** The provider's major-unit decimal string → minor units, exactly, or
 * null when the string is not plain `[-]digits[.digits]`, carries more
 * fractional digits than the currency, names an unreviewed currency, or
 * lies outside ±(2^53 − 1). Never `* 100`, never a float. */
export const toMinor = (major: string | undefined | null, currency: string): number | null => {
  if (major == null) return null;
  const exponent = exponentOf(currency);
  if (exponent === null) return null;
  const m = /^(-?)(\d+)(?:\.(\d+))?$/.exec(major.trim());
  if (!m) return null;
  const fraction = m[3] ?? "";
  if (fraction.length > exponent) return null;
  const units = BigInt(`${m[1]}${m[2]}${fraction}`) * 10n ** BigInt(exponent - fraction.length);
  if (!inRange(units)) return null;
  return Number(units);
};

/** The wire form shared with the app (accounting_amount.dart `toJson`):
 * the minor units travel as a string of digits so no JSON reader rounds
 * them, beside the currency and its exponent. */
export interface AccountingAmountWire {
  currency: string;
  exponent: number;
  minor: string;
}

export const toWire = (minor: number | bigint, currency: string): AccountingAmountWire => {
  const code = currency.trim().toUpperCase();
  const exponent = exponentOf(code);
  if (exponent === null) throw new MoneyRefusal("unsupported_currency", code);
  return { currency: code, exponent, minor: asInteger(minor, code).toString() };
};

/** Reads the wire form with the app's own checks: a currency with a
 * reviewed exponent that EQUALS the one sent, minor units as a plain
 * integer string within range. Anything else is null, never a guess. */
export const fromWire = (
  json: unknown,
): { currency: string; exponent: number; minor: number } | null => {
  if (typeof json !== "object" || json === null) return null;
  const j = json as Record<string, unknown>;
  if (typeof j.currency !== "string") return null;
  const code = j.currency.trim().toUpperCase();
  const exponent = exponentOf(code);
  if (exponent === null || j.exponent !== exponent) return null;
  if (typeof j.minor !== "string" || !/^-?\d+$/.test(j.minor)) return null;
  const v = BigInt(j.minor);
  if (!inRange(v)) return null;
  return { currency: code, exponent, minor: Number(v) };
};
