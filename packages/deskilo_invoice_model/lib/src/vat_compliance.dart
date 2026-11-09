// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #878 — the VAT rules the review pinned down as code: the mention a
// member state expects on an exempt or out-of-scope invoice when the
// owner wrote none, and the shape a European VAT identifier has to
// have before an e-invoice names it (a syntactic check; a VIES lookup
// is #895). Reviewed against Council Directive 2006/112/EC (art. 226,
// 289 CGI for France, § 19 UStG for Germany) and EN 16931 BR-E-10.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';

import 'place_of_supply.dart' show uncl5305ReverseCharge;
import 'vat_regime.dart';
import 'national_invoice_rules.dart';

// #3333: the Canadian registration numbers live in the standards package, one
// copy for the application and the Canadian add-on.
export 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show
        formatCanadianRegistration,
        formatSwissUid,
        isValidCanadianBn,
        isValidQstNumber,
        isValidSwissUid;

// #2354 — the EU set and the place-of-supply rule live in core/vat (pure,
// shared with the member screens); money code keeps importing them here.
export 'place_of_supply.dart';

/// The statutory mention for a seller that charges no VAT, per country,
/// used when the owner left the exemption reason empty (BT-120 must
/// not be blank on a category E invoice, BR-E-10).
///
/// #2478 — the texts are rows of the tax reference store (`exemption_text`,
/// a country's own row or the shared `*` one); [asOf] names the day of the
/// document, so a text changed later never reaches an issued one.
///
/// #2356 — an exempt seller using the small-enterprise scheme of ANOTHER
/// member state (Directive 2020/285, since 2025) prints the identification
/// number with the `EX` suffix that state gave it, and says which scheme
/// (the `exempt_ex` text, whose `{vat_id}` is the number).
String defaultExemptionMention(
  String countryCode,
  VatRegime regime, {
  String vatId = '',
  String? asOf,
  required TaxReferenceSet reference,
}) {
  final set = reference;
  if (regime == VatRegime.exempt && _isExNumber(vatId)) {
    return (set.mentionFor('exempt_ex', countryCode, asOf: asOf) ?? '')
        .replaceAll('{vat_id}', vatId.trim());
  }
  return switch (regime) {
    VatRegime.vatRegistered => '',
    VatRegime.exempt => set.mentionFor('exempt', countryCode, asOf: asOf) ?? '',
    VatRegime.notSubject =>
      set.mentionFor('not_subject', countryCode, asOf: asOf) ?? '',
  };
}

/// #2356 — whether [vatId] is an identification number of the EU
/// small-enterprise scheme (the `EX` suffix).
bool _isExNumber(String vatId) {
  final id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  return id.length > 6 && id.endsWith('EX');
}

/// Whether [vatId] has the shape its member state prescribes (the
/// VIES syntax, spaces and punctuation ignored). A prefix the table
/// does not know is NOT flagged — the check exists to catch typos in
/// the countries an e-invoice will actually meet, not to refuse the
/// world. An empty id is not a VAT id at all and returns false.
bool looksLikeEuVatId(String vatId, {String? asOf, required TaxReferenceSet reference}) {
  var id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  // #2356 — the EU small-enterprise scheme's number is the national one
  // with an `EX` suffix (art. 284(3) of the Directive).
  if (_isExNumber(id)) id = id.substring(0, id.length - 2);
  if (id.length < 4) return false;
  final prefix = id.substring(0, 2);
  final body = id.substring(2);
  final pattern = reference.vatIdBody(prefix, asOf: asOf);
  if (pattern == null) return true;
  return RegExp('^(?:$pattern)\$').hasMatch(body);
}

/// The mention such a document must carry (BT-120), in the seller's
/// language — the customer reads it as the reason no tax is charged.
String reverseChargeMention(String sellerCountry,
        {String? asOf, required TaxReferenceSet reference}) =>
    reference
        .mentionFor('reverse_charge', sellerCountry, asOf: asOf) ??
    '';

/// The VATEX code for a category, when the code lists have one.
String exemptionCodeForCategory(
  String category,
  String sellerCountry,
  VatRegime regime,
  NationalInvoiceRules rules,
) =>
    switch (category) {
      uncl5305ReverseCharge => 'VATEX-EU-AE',
      // #985 — outside the EU.
      'G' => 'VATEX-EU-G',
      _ => regime.exemptionReasonCode(sellerCountry, rules: rules),
    };

/// #985 — the mention a supply outside the EU prints. #2354: only a
/// general service to a business established outside the EU is one
/// (art. 44) — never a desk, which is supplied where the building stands.
String exportMention(String sellerCountry,
        {String? asOf, required TaxReferenceSet reference}) =>
    reference
        .mentionFor('export', sellerCountry, asOf: asOf) ??
    '';

/// #985 — the exemption text a document prints for [category]: the
/// statutory mention for AE and G, the buyer's own reason for an exempt
/// buyer of a VAT-charging seller, the seller's text otherwise.
String exemptionMentionFor({
  required String category,
  required String sellerCountry,
  required String sellerReason,
  required String buyerReason,
  required VatRegime regime,
  required TaxReferenceSet reference,
  String? asOf,
}) =>
    switch (category) {
      uncl5305ReverseCharge => reverseChargeMention(sellerCountry, asOf: asOf, reference: reference),
      'G' => exportMention(sellerCountry, asOf: asOf, reference: reference),
      'E' when regime == VatRegime.vatRegistered &&
              buyerReason.trim().isNotEmpty =>
        buyerReason.trim(),
      _ => sellerReason,
    };

/// #896 — the mention a seller must print about WHEN its tax falls due.
/// France REQUIRES one when the seller opted for the debits, in the
/// words of CGI art. 242 nonies A, I-13° (« Option pour le paiement de
/// la taxe d'après les débits », #2355); on receipts — the legal rule for
/// services — it says so. Elsewhere it is said once, plainly, and harms
/// nothing; Italy's per cassa and Spain's criterio de caja mentions are
/// statutory too. [onPaymentBasis] is whether the tax waits for the
/// money (`VatTaxPointBasis.onReceipts`). Empty for a seller that
/// charges no VAT — there is no tax to be due.
String exigibilityMention({
  required VatRegime regime,
  required String sellerCountry,
  required bool onPaymentBasis,
  String? asOf,
  required TaxReferenceSet reference,
}) {
  if (regime != VatRegime.vatRegistered) return '';
  return reference.mentionFor(
        onPaymentBasis ? 'exigibility_receipts' : 'exigibility_invoices',
        sellerCountry,
        asOf: asOf,
      ) ??
      '';
}
