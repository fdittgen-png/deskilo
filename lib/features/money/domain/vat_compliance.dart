// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #878 — the VAT rules the review pinned down as code: the mention a
// member state expects on an exempt or out-of-scope invoice when the
// owner wrote none, and the shape a European VAT identifier has to
// have before an e-invoice names it (a syntactic check; a VIES lookup
// is #895). Reviewed against Council Directive 2006/112/EC (art. 226,
// 289 CGI for France, § 19 UStG for Germany) and EN 16931 BR-E-10.
import '../../../core/vat/place_of_supply.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'vat_regime.dart';

// #2354 — the EU set and the place-of-supply rule live in core/vat (pure,
// shared with the member screens); money code keeps importing them here.
export '../../../core/vat/place_of_supply.dart';

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
  TaxReferenceSet? reference,
}) {
  final set = reference ?? ActiveTaxReference.current;
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
bool looksLikeEuVatId(String vatId, {String? asOf, TaxReferenceSet? reference}) {
  var id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  // #2356 — the EU small-enterprise scheme's number is the national one
  // with an `EX` suffix (art. 284(3) of the Directive).
  if (_isExNumber(id)) id = id.substring(0, id.length - 2);
  if (id.length < 4) return false;
  final prefix = id.substring(0, 2);
  final body = id.substring(2);
  final pattern = (reference ?? ActiveTaxReference.current).vatIdBody(prefix, asOf: asOf);
  if (pattern == null) return true;
  return RegExp('^(?:$pattern)\$').hasMatch(body);
}

/// #2360 — the Swiss UID (Unternehmens-Identifikationsnummer) of a
/// VAT-registered seller: `CHE-123.456.789 MWST` (art. 26 Abs. 2 lit. a
/// MWSTG; `TVA` and `IVA` in French and Italian). The ninth digit checks
/// the first eight (modulus 11, weights 5 4 3 2 7 6 5 4). The server twin
/// is `swiss_uid_valid` (migration 0420).
bool isValidSwissUid(String uid, {bool requireSuffix = true}) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE(\d{9})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null || (requireSuffix && m.group(2) == null)) return false;
  final digits = m.group(1)!.codeUnits.map((c) => c - 48).toList();
  const weights = [5, 4, 3, 2, 7, 6, 5, 4];
  var sum = 0;
  for (var i = 0; i < 8; i++) {
    sum += digits[i] * weights[i];
  }
  final check = 11 - sum % 11;
  return check != 10 && (check == 11 ? 0 : check) == digits[8];
}

/// The UID as it prints: `CHE-123.456.789 MWST`. Anything that is not
/// shaped like a UID is returned as typed.
String formatSwissUid(String uid) {
  final id = uid.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^CHE(\d{3})(\d{3})(\d{3})(MWST|TVA|IVA)?$').firstMatch(id);
  if (m == null) return uid;
  return 'CHE-${m[1]}.${m[2]}.${m[3]}${m[4] == null ? '' : ' ${m[4]}'}';
}

/// #2361 — the business number of a GST/HST registrant with its RT account:
/// `123456789 RT0001` (ETA s. 169(4); Input Tax Credit Information
/// Regulations). The server twin is the pattern in
/// `invoice_essentials_missing` (migration 0424).
bool isValidCanadianBn(String bn) => RegExp(r'^\d{9}RT\d{4}$')
    .hasMatch(bn.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''));

/// #2361 — Revenu Québec's QST registration number: `1234567890 TQ0001`.
bool isValidQstNumber(String number) => RegExp(r'^\d{10}TQ\d{4}$')
    .hasMatch(number.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''));

/// A Canadian registration number as it prints: `123456789 RT0001`,
/// `1234567890 TQ0001`. Anything else is returned as typed.
String formatCanadianRegistration(String number) {
  final id = number.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  final m = RegExp(r'^(\d{9}|\d{10})(RT|TQ)(\d{4})$').firstMatch(id);
  if (m == null) return number;
  return '${m[1]} ${m[2]}${m[3]}';
}

/// The mention such a document must carry (BT-120), in the seller's
/// language — the customer reads it as the reason no tax is charged.
String reverseChargeMention(String sellerCountry,
        {String? asOf, TaxReferenceSet? reference}) =>
    (reference ?? ActiveTaxReference.current)
        .mentionFor('reverse_charge', sellerCountry, asOf: asOf) ??
    '';

/// The VATEX code for a category, when the code lists have one.
String exemptionCodeForCategory(
  String category,
  String sellerCountry,
  VatRegime regime,
) =>
    switch (category) {
      'AE' => 'VATEX-EU-AE',
      // #985 — outside the EU.
      'G' => 'VATEX-EU-G',
      _ => regime.exemptionReasonCode(sellerCountry),
    };

/// #985 — the mention a supply outside the EU prints. #2354: only a
/// general service to a business established outside the EU is one
/// (art. 44) — never a desk, which is supplied where the building stands.
String exportMention(String sellerCountry,
        {String? asOf, TaxReferenceSet? reference}) =>
    (reference ?? ActiveTaxReference.current)
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
  String? asOf,
}) =>
    switch (category) {
      'AE' => reverseChargeMention(sellerCountry, asOf: asOf),
      'G' => exportMention(sellerCountry, asOf: asOf),
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
  TaxReferenceSet? reference,
}) {
  if (regime != VatRegime.vatRegistered) return '';
  return (reference ?? ActiveTaxReference.current).mentionFor(
        onPaymentBasis ? 'exigibility_receipts' : 'exigibility_invoices',
        sellerCountry,
        asOf: asOf,
      ) ??
      '';
}

/// #2356 — what a member state's own law adds to an invoice beyond the
/// Directive's list (art. 226), in the seller's language:
///  * Italy — the € 2 stamp duty on an invoice whose amount not subject to
///    VAT exceeds € 77.47 (D.P.R. 642/1972, tariff art. 13);
///  * Spain — a correcting invoice says it is one and names the invoice it
///    rectifies (RD 1619/2012 art. 15);
///  * France — the category of the operation (CGI ann. II art. 242
///    nonies A, since the 2026 e-invoicing reform): a workspace supplies
///    services.
/// [untaxedCents] is the gross of the supplies that carry no VAT other
/// than a reverse charge; [correction] a credit note or a replacement.
List<String> nationalInvoiceMentions({
  required String sellerCountry,
  required VatRegime regime,
  required String currency,
  required int untaxedCents,
  required bool correction,
  String rectifies = '',
  String correctionReason = '',
  String sellerVatId = '',
  String sellerLegalId = '',
  bool qstCharged = false,
}) {
  final country = euCountryCode(sellerCountry);
  final reason = _spanishCorrectionReasonText(correctionReason);
  return [
    if (country == 'IT' && currency.toUpperCase() == 'EUR' && untaxedCents > 7747)
      'Imposta di bollo da € 2,00 assolta ai sensi del D.P.R. 642/1972.',
    if (country == 'ES' && correction && rectifies.trim().isEmpty)
      'Factura rectificativa (art. 15 del RD 1619/2012)'
          '${reason.isEmpty ? '.' : '. Motivo: $reason.'}'
    else if (country == 'ES' && correction)
      'Factura rectificativa (art. 15 del RD 1619/2012) de la factura '
          '${rectifies.trim()}${reason.isEmpty ? '.' : '. Motivo: $reason.'}',
    if (country == 'FR' && regime == VatRegime.vatRegistered)
      "Catégorie de l'opération : prestation de services.",
    // #2361 — a Canadian invoice states the registrant's numbers (ETA s.
    // 169(4); the Act respecting the QST, s. 425), in both languages: the
    // customer's decides which is read, the law asks for the number.
    if (country == 'CA' &&
        regime == VatRegime.vatRegistered &&
        sellerVatId.trim().isNotEmpty)
      'GST/HST No. · N° de TPS/TVH : '
          '${formatCanadianRegistration(sellerVatId)}',
    if (country == 'CA' &&
        regime == VatRegime.vatRegistered &&
        qstCharged &&
        sellerLegalId.trim().isNotEmpty)
      'QST No. · N° de TVQ : ${formatCanadianRegistration(sellerLegalId)}',
  ];
}

/// #2440 — the correction codes of RD 1619/2012 art. 15 (AEAT TipoFactura
/// R1-R5), as the Spanish mention words them. Empty for anything else.
const spanishCorrectionReasonCodes = ['R1', 'R2', 'R3', 'R4', 'R5'];

String _spanishCorrectionReasonText(String code) =>
    switch (code.trim().toUpperCase()) {
      'R1' => 'R1, error fundado en derecho y causas del art. 80 uno, dos '
          'y seis de la Ley 37/1992',
      'R2' => 'R2, concurso de acreedores (art. 80 tres de la Ley 37/1992)',
      'R3' => 'R3, créditos incobrables (art. 80 cuatro de la Ley 37/1992)',
      'R4' => 'R4, resto de causas',
      'R5' => 'R5, factura simplificada',
      _ => '',
    };
