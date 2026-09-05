// SPDX-License-Identifier: 0BSD
//
// #878 — the VAT rules the review pinned down as code: the mention a
// member state expects on an exempt or out-of-scope invoice when the
// owner wrote none, and the shape a European VAT identifier has to
// have before an e-invoice names it (a syntactic check; a VIES lookup
// is #895). Reviewed against Council Directive 2006/112/EC (art. 226,
// 289 CGI for France, § 19 UStG for Germany) and EN 16931 BR-E-10.
import 'vat_regime.dart';

/// The statutory mention for a seller that charges no VAT, per country,
/// used when the owner left the exemption reason empty (BT-120 must
/// not be blank on a category E invoice, BR-E-10).
String defaultExemptionMention(String countryCode, VatRegime regime) {
  final country = countryCode.trim().toUpperCase();
  return switch (regime) {
    VatRegime.vatRegistered => '',
    VatRegime.exempt => switch (country) {
        'FR' => 'TVA non applicable, art. 293 B du CGI',
        'DE' => 'Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.',
        'AT' => 'Umsatzsteuerbefreit gemäß § 6 Abs. 1 Z 27 UStG '
            '(Kleinunternehmer).',
        'ES' => 'Operación exenta de IVA (régimen de franquicia, '
            'art. 163 quinquies Ley 37/1992).',
        'IT' => "Operazione senza applicazione dell'IVA ai sensi "
            "dell'art. 1, commi 54-89, L. 190/2014.",
        'BE' => 'Régime particulier de franchise des petites entreprises '
            '(art. 56bis CTVA) — TVA non applicable.',
        'NL' => 'Vrijgesteld van btw (kleineondernemersregeling, '
            'art. 25 Wet OB).',
        'LU' => 'Franchise de TVA, art. 57 de la loi TVA.',
        _ => 'VAT exempt — Council Directive 2006/112/EC (small '
            'enterprise scheme, art. 282–292).',
      },
    VatRegime.notSubject => switch (country) {
        'FR' => 'TVA non applicable — opération hors champ '
            '(art. 256 B du CGI).',
        'DE' => 'Nicht umsatzsteuerbar — kein Unternehmer im Sinne '
            'des § 2 UStG.',
        _ => 'Not subject to VAT — outside the scope of Council '
            'Directive 2006/112/EC.',
      },
  };
}

/// Whether [vatId] has the shape its member state prescribes (the
/// VIES syntax, spaces and punctuation ignored). A prefix the table
/// does not know is NOT flagged — the check exists to catch typos in
/// the countries an e-invoice will actually meet, not to refuse the
/// world. An empty id is not a VAT id at all and returns false.
bool looksLikeEuVatId(String vatId) {
  final id = vatId.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
  if (id.length < 4) return false;
  final prefix = id.substring(0, 2);
  final body = id.substring(2);
  final pattern = _vatIdBodies[prefix];
  if (pattern == null) return true;
  return RegExp('^$pattern\$').hasMatch(body);
}

/// The identifier body per member state (VIES formats; EL is Greece's
/// prefix, XI Northern Ireland's).
const Map<String, String> _vatIdBodies = {
  'AT': r'U\d{8}',
  'BE': r'[01]\d{9}',
  'BG': r'\d{9,10}',
  'CY': r'\d{8}[A-Z]',
  'CZ': r'\d{8,10}',
  'DE': r'\d{9}',
  'DK': r'\d{8}',
  'EE': r'\d{9}',
  'EL': r'\d{9}',
  'ES': r'[A-Z0-9]\d{7}[A-Z0-9]',
  'FI': r'\d{8}',
  'FR': r'[A-Z0-9]{2}\d{9}',
  'HR': r'\d{11}',
  'HU': r'\d{8}',
  'IE': r'\d{7}[A-Z]{1,2}|\d[A-Z+*]\d{5}[A-Z]',
  'IT': r'\d{11}',
  'LT': r'\d{9}|\d{12}',
  'LU': r'\d{8}',
  'LV': r'\d{11}',
  'MT': r'\d{8}',
  'NL': r'\d{9}B\d{2}',
  'PL': r'\d{10}',
  'PT': r'\d{9}',
  'RO': r'\d{2,10}',
  'SE': r'\d{12}',
  'SI': r'\d{8}',
  'SK': r'\d{10}',
  'XI': r'\d{9}|\d{12}|GD\d{3}|HA\d{3}',
  'CH': r'E\d{9}(MWST|TVA|IVA)?',
};

/// #895 — the member states whose businesses self-assess the tax on a
/// cross-border supply (EL is Greece's VAT prefix).
const Set<String> euMemberStates = {
  'AT','BE','BG','CY','CZ','DE','DK','EE','ES','FI','FR','GR','EL','HR','HU',
  'IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK',
};

bool isEuCountry(String code) =>
    euMemberStates.contains(code.trim().toUpperCase());

/// Whether a supply is REVERSE-CHARGED: a VAT-registered seller invoicing
/// a business in ANOTHER member state charges no tax — the customer
/// self-assesses (Directive art. 196). Mirrors `create_invoice` (0157);
/// a workspace that never invoices businesses abroad opts out.
bool reverseChargeApplies({
  required VatRegime sellerRegime,
  required String sellerCountry,
  required String buyerCountry,
  required String buyerVatId,
  bool optedOut = false,
}) =>
    !optedOut &&
    sellerRegime == VatRegime.vatRegistered &&
    buyerVatId.trim().isNotEmpty &&
    isEuCountry(sellerCountry) &&
    isEuCountry(buyerCountry) &&
    sellerCountry.trim().toUpperCase() != buyerCountry.trim().toUpperCase();

/// The mention such a document must carry (BT-120), in the seller's
/// language — the customer reads it as the reason no tax is charged.
String reverseChargeMention(String sellerCountry) =>
    switch (sellerCountry.trim().toUpperCase()) {
      'FR' => 'Autoliquidation — TVA due par le preneur '
          '(art. 196 de la directive 2006/112/CE).',
      'DE' || 'AT' => 'Steuerschuldnerschaft des Leistungsempfängers '
          '(Art. 196 der Richtlinie 2006/112/EG).',
      'ES' => 'Inversión del sujeto pasivo '
          '(art. 196 de la Directiva 2006/112/CE).',
      'IT' => "Inversione contabile — imposta assolta dal committente "
          "(art. 196 della direttiva 2006/112/CE).",
      'NL' => 'Btw verlegd (art. 196 richtlijn 2006/112/EG).',
      'PT' => 'Autoliquidação (art. 196.º da Diretiva 2006/112/CE).',
      _ => 'Reverse charge — VAT due by the customer '
          '(art. 196 of Council Directive 2006/112/EC).',
    };

/// The VATEX code for a category, when the code lists have one.
String exemptionCodeForCategory(
  String category,
  String sellerCountry,
  VatRegime regime,
) =>
    category == 'AE'
        ? 'VATEX-EU-AE'
        : regime.exemptionReasonCode(sellerCountry);
