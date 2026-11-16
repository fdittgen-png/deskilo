// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4135 -- what a payer reads at the provider: the name of the business they
// pay and the payment's reference ("Atelier du Marché — PAY-2026-0117"), the
// same rule for every provider, within the provider's own limit. The
// reference is never cut; a name too long for the room left is shortened and
// says so ("…"). The business's name comes from the business, never from
// code: no product name in a text a payer reads.

/** How many characters each provider shows of the text (Stripe Checkout's
 * product name, Mollie's description, PayPal's purchase unit description). */
export const PAYER_TEXT_LIMITS = {
  stripe: 250,
  mollie: 255,
  paypal: 127,
} as const;

const SEPARATOR = " — ";

/** [text] without what a provider refuses or shows as noise: control and
 * format characters become spaces, runs of spaces one space. */
function clean(text: string): string {
  return text.replace(/[\p{Cc}\p{Cf}]/gu, " ").replace(/\s+/g, " ").trim();
}

/** The text a payer reads for a payment of [payee] under [reference], at
 * most [limit] characters (counted as the payer sees them). */
export function payerText(
  payee: string,
  reference: string,
  limit: number,
): string {
  const ref = clean(reference);
  const name = [...clean(payee)];
  const room = limit - [...ref].length - SEPARATOR.length;
  if (name.length === 0 || room < 2) return ref;
  const shown = name.length <= room
    ? name.join("")
    : name.slice(0, room - 1).join("").trimEnd() + "…";
  return `${shown}${SEPARATOR}${ref}`;
}
