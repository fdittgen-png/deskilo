// SPDX-License-Identifier: 0BSD
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
const ZERO_DECIMAL = new Set([
  "BIF","CLP","DJF","GNF","ISK","JPY","KMF","KRW","PYG","RWF","UGX","VND","VUV","XAF","XOF","XPF",
]);
const THREE_DECIMAL = new Set(["BHD","IQD","JOD","KWD","LYD","OMR","TND"]);

export const minorDigits = (currency: string): number =>
  ZERO_DECIMAL.has(currency.toUpperCase()) ? 0
    : THREE_DECIMAL.has(currency.toUpperCase()) ? 3 : 2;

/** Minor units → the provider's major-unit decimal string ("10.00", "1000"). */
export const toMajor = (minor: number, currency: string): string =>
  (minor / 10 ** minorDigits(currency)).toFixed(minorDigits(currency));

/** The provider's major-unit decimal string → minor units, or null when
 * the string is not a number. Never `* 100`. */
export const toMinor = (major: string | undefined | null, currency: string): number | null => {
  if (major == null || major === "") return null;
  const n = Number(major);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 10 ** minorDigits(currency));
};
