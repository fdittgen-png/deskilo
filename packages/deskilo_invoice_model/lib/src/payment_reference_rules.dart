// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what the payment-reference logic needs to know about
// countries, handed in by the host from the installed payment slip add-ons:
// this package names no country. A QR-IBAN is an IBAN of one of these
// countries whose institution identifier is in the QR range.

/// The countries whose IBANs a payment slip accepts (the Swiss QR bill:
/// Switzerland and Liechtenstein). Required wherever a QR-IBAN is judged, so a
/// caller that forgets it cannot silently treat every account as an ordinary
/// one.
class PaymentReferenceRules {
  const PaymentReferenceRules({required this.accountCountries});

  /// Upper-case ISO country codes.
  final Set<String> accountCountries;
}
