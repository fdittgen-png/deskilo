// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what the e-invoice logic needs to know about countries,
// handed in by the host from the installed invoice mentions add-ons: this
// package names no country.
import 'payment_reference_rules.dart';

/// The national decisions of an e-invoice: which countries ask the buyer's
/// legal id between two of their own businesses, and the VATEX code a seller
/// of a country names for a VAT exemption. Required wherever either is judged,
/// so a caller that forgets it cannot silently drop a country's rule.
class NationalInvoiceRules {
  const NationalInvoiceRules({
    required this.domesticBuyerLegalIdCountries,
    required this.exemptionReasonCodes,
  });

  /// Upper-case ISO codes of the countries whose domestic business-to-business
  /// e-invoice must name the buyer's legal id.
  final Set<String> domesticBuyerLegalIdCountries;

  /// The VATEX exemption code by upper-case ISO country code.
  final Map<String, String> exemptionReasonCodes;

  /// The code a seller of [countryCode] names for an exemption; '' when none.
  String exemptionReasonCodeOf(String countryCode) =>
      exemptionReasonCodes[countryCode.trim().toUpperCase()] ?? '';

  /// Whether both [seller] and [buyer] countries are one that asks the buyer's
  /// legal id of a domestic business-to-business e-invoice.
  bool asksBuyerLegalId(String seller, String buyer) {
    final s = seller.trim().toUpperCase();
    return domesticBuyerLegalIdCountries.contains(s) &&
        buyer.trim().toUpperCase() == s;
  }
}

/// What a document's checks need beyond the invoice: the account it names and
/// the national rules it is judged by. One argument, so a caller cannot pass
/// the account without the rules.
class InvoiceAccount {
  const InvoiceAccount({required this.payment, required this.national});

  final PaymentAccount payment;
  final NationalInvoiceRules national;
}
