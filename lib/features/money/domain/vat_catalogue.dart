// SPDX-License-Identifier: 0BSD
import 'vat_rate.dart';

/// The rates a country actually charges, so a workspace can start from its
/// own reality instead of typing percentages out of a tax leaflet (0072,
/// expanded #534 to every EU member state, Switzerland, Norway and the
/// Canadian provinces).
///
/// These are STARTING POINTS the owner then edits, not tax advice: rates
/// move, and which one applies to a given supply is a question for an
/// accountant. Only the standard rate is marked default — that is what
/// coworking membership normally falls under. Verified 2026-08 against the
/// Tax Foundation EU table + skatteetaten.no + estv.admin.ch + CRA.
const Map<String, List<({String label, double percent, VatGroup group})>>
    _catalogue = {
  // ── EU 27 ──────────────────────────────────────────────────────────
  'AT': [
    (label: 'Normalsatz 20 %', percent: 20, group: VatGroup.standard),
    (label: 'Ermäßigt 13 %', percent: 13, group: VatGroup.intermediate),
    (label: 'Ermäßigt 10 %', percent: 10, group: VatGroup.reduced),
  ],
  'BE': [
    (label: 'Standaard 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Verlaagd 12 %', percent: 12, group: VatGroup.intermediate),
    (label: 'Verlaagd 6 %', percent: 6, group: VatGroup.reduced),
  ],
  'BG': [
    (label: 'Стандартна 20 %', percent: 20, group: VatGroup.standard),
    (label: 'Намалена 9 %', percent: 9, group: VatGroup.reduced),
  ],
  'HR': [
    (label: 'Standardna 25 %', percent: 25, group: VatGroup.standard),
    (label: 'Snižena 13 %', percent: 13, group: VatGroup.intermediate),
    (label: 'Snižena 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'CY': [
    (label: 'Standard 19 %', percent: 19, group: VatGroup.standard),
    (label: 'Reduced 9 %', percent: 9, group: VatGroup.intermediate),
    (label: 'Reduced 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'CZ': [
    (label: 'Základní 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Snížená 12 %', percent: 12, group: VatGroup.reduced),
  ],
  'DK': [
    (label: 'Standard 25 %', percent: 25, group: VatGroup.standard),
  ],
  'EE': [
    (label: 'Standardmäär 24 %', percent: 24, group: VatGroup.standard),
    (label: 'Vähendatud 13 %', percent: 13, group: VatGroup.intermediate),
    (label: 'Vähendatud 9 %', percent: 9, group: VatGroup.reduced),
  ],
  'FI': [
    (label: 'Yleinen 25,5 %', percent: 25.5, group: VatGroup.standard),
    (label: 'Alennettu 13,5 %', percent: 13.5, group: VatGroup.intermediate),
    (label: 'Alennettu 10 %', percent: 10, group: VatGroup.reduced),
  ],
  'FR': [
    (label: 'Standard 20 %', percent: 20, group: VatGroup.standard),
    (label: 'Intermédiaire 10 %', percent: 10, group: VatGroup.intermediate),
    (label: 'Réduit 5,5 %', percent: 5.5, group: VatGroup.reduced),
    (label: 'Particulier 2,1 %', percent: 2.1, group: VatGroup.superReduced),
  ],
  'DE': [
    (label: 'Regelsatz 19 %', percent: 19, group: VatGroup.standard),
    (label: 'Ermäßigt 7 %', percent: 7, group: VatGroup.reduced),
  ],
  'GR': [
    (label: 'Κανονικός 24 %', percent: 24, group: VatGroup.standard),
    (label: 'Μειωμένος 13 %', percent: 13, group: VatGroup.intermediate),
    (label: 'Μειωμένος 6 %', percent: 6, group: VatGroup.reduced),
  ],
  'HU': [
    (label: 'Általános 27 %', percent: 27, group: VatGroup.standard),
    (label: 'Kedvezményes 18 %', percent: 18, group: VatGroup.intermediate),
    (label: 'Kedvezményes 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'IE': [
    (label: 'Standard 23 %', percent: 23, group: VatGroup.standard),
    (label: 'Reduced 13.5 %', percent: 13.5, group: VatGroup.intermediate),
    (label: 'Reduced 9 %', percent: 9, group: VatGroup.reduced),
    (label: 'Livestock 4.8 %', percent: 4.8, group: VatGroup.superReduced),
  ],
  'IT': [
    (label: 'Ordinaria 22 %', percent: 22, group: VatGroup.standard),
    (label: 'Ridotta 10 %', percent: 10, group: VatGroup.intermediate),
    (label: 'Ridotta 5 %', percent: 5, group: VatGroup.reduced),
    (label: 'Minima 4 %', percent: 4, group: VatGroup.superReduced),
  ],
  'LV': [
    (label: 'Standarta 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Samazinātā 12 %', percent: 12, group: VatGroup.intermediate),
    (label: 'Samazinātā 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'LT': [
    (label: 'Standartinis 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Lengvatinis 9 %', percent: 9, group: VatGroup.intermediate),
    (label: 'Lengvatinis 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'LU': [
    (label: 'Normal 17 %', percent: 17, group: VatGroup.standard),
    (label: 'Intermédiaire 14 %', percent: 14, group: VatGroup.intermediate),
    (label: 'Réduit 8 %', percent: 8, group: VatGroup.reduced),
    (label: 'Super-réduit 3 %', percent: 3, group: VatGroup.superReduced),
  ],
  'MT': [
    (label: 'Standard 18 %', percent: 18, group: VatGroup.standard),
    (label: 'Reduced 7 %', percent: 7, group: VatGroup.intermediate),
    (label: 'Reduced 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'NL': [
    (label: 'Hoog 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Laag 9 %', percent: 9, group: VatGroup.reduced),
  ],
  'PL': [
    (label: 'Podstawowa 23 %', percent: 23, group: VatGroup.standard),
    (label: 'Obniżona 8 %', percent: 8, group: VatGroup.intermediate),
    (label: 'Obniżona 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'PT': [
    (label: 'Normal 23 %', percent: 23, group: VatGroup.standard),
    (label: 'Intermédia 13 %', percent: 13, group: VatGroup.intermediate),
    (label: 'Reduzida 6 %', percent: 6, group: VatGroup.reduced),
  ],
  'RO': [
    (label: 'Standard 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Redusă 11 %', percent: 11, group: VatGroup.reduced),
  ],
  'SK': [
    (label: 'Základná 23 %', percent: 23, group: VatGroup.standard),
    (label: 'Znížená 19 %', percent: 19, group: VatGroup.intermediate),
    (label: 'Znížená 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'SI': [
    (label: 'Splošna 22 %', percent: 22, group: VatGroup.standard),
    (label: 'Znižana 9,5 %', percent: 9.5, group: VatGroup.intermediate),
    (label: 'Znižana 5 %', percent: 5, group: VatGroup.reduced),
  ],
  'ES': [
    (label: 'General 21 %', percent: 21, group: VatGroup.standard),
    (label: 'Reducido 10 %', percent: 10, group: VatGroup.reduced),
    (label: 'Superreducido 4 %', percent: 4, group: VatGroup.superReduced),
  ],
  'SE': [
    (label: 'Standard 25 %', percent: 25, group: VatGroup.standard),
    (label: 'Reducerad 12 %', percent: 12, group: VatGroup.intermediate),
    (label: 'Reducerad 6 %', percent: 6, group: VatGroup.reduced),
  ],
  // ── Non-EU Europe ──────────────────────────────────────────────────
  'CH': [
    (label: 'Normal 8,1 %', percent: 8.1, group: VatGroup.standard),
    (label: 'Hébergement 3,8 %', percent: 3.8, group: VatGroup.intermediate),
    (label: 'Réduit 2,6 %', percent: 2.6, group: VatGroup.reduced),
  ],
  'NO': [
    (label: 'Alminnelig 25 %', percent: 25, group: VatGroup.standard),
    (label: 'Næringsmidler 15 %', percent: 15, group: VatGroup.intermediate),
    (label: 'Redusert 12 %', percent: 12, group: VatGroup.reduced),
  ],
  // ── North America ──────────────────────────────────────────────────
  // Canada: GST is federal; the usable rate depends on the PROVINCE, so
  // the catalogue lists the per-province combined realities. The owner
  // keeps the one that applies and deletes the rest.
  'CA': [
    (label: 'GST 5 % (AB/NT/NU/YT)', percent: 5, group: VatGroup.standard),
    (label: 'HST 13 % (ON)', percent: 13, group: VatGroup.standard),
    (label: 'HST 14 % (NS)', percent: 14, group: VatGroup.standard),
    (label: 'HST 15 % (NB/NL/PE)', percent: 15, group: VatGroup.standard),
    (label: 'GST+QST 14,975 % (QC)', percent: 14.975, group: VatGroup.standard),
    (label: 'GST+PST 12 % (BC/MB)', percent: 12, group: VatGroup.standard),
    (label: 'GST+PST 11 % (SK)', percent: 11, group: VatGroup.standard),
  ],
  // US: deliberately NO preset — there is no federal VAT/sales tax and
  // state+local rates vary by the seller's nexus; vatCatalogueNote says
  // so. The owner types the local combined rate.
};

/// Whether a country's usual rates are known — the seed button only shows
/// when there is something to seed.
bool hasVatCatalogue(String countryCode) =>
    _catalogue.containsKey(countryCode.toUpperCase());

/// The country's usual rates as editable [VatRate]s, standard first and
/// marked as the default.
/// Every country the catalogue knows.
Iterable<String> get vatCatalogueCountries => _catalogue.keys;

List<VatRate> vatCatalogueFor(String countryCode) => [
      for (final (index, rate)
          in (_catalogue[countryCode.toUpperCase()] ?? const []).indexed)
        VatRate(
          label: rate.label,
          percent: rate.percent,
          isDefault: index == 0,
          // #985 — the group is the catalogue's, not a guess from the number.
          category: rate.group.category,
          groupKey: rate.group.wire,
          outsideBase: rate.group.outsideBase,
        ),
    ];

/// Which of the seeded rates should NOT default: Canada seeds several
/// per-province realities — the first (plain GST) defaults, the rest are
/// alternatives to prune. Everything else keeps rate[0] as default.
///
/// A short country-specific caveat shown next to the seed button (#534):
/// the moments where "here are your country's rates" needs an asterisk.
String? vatCatalogueNote(String countryCode) => switch (countryCode.toUpperCase()) {
      'US' =>
        'The US has no federal VAT — sales tax is set by state and locality. '
            'Add your local combined rate manually.',
      'CA' =>
        'Canada taxes by province: keep the line for yours (GST, HST, or '
            'GST+PST/QST) and delete the rest.',
      'CH' =>
        'The 3.8 % special rate applies to accommodation only.',
      _ => null,
    };


/// #947 — what falls in each group, country by country: starting points
/// for the owner, not tax advice. A country with no entry gets the
/// EU-wide shape.
List<({VatGroup group, String example})> vatGroupExamples(String countryCode) =>
    switch (countryCode.toUpperCase()) {
      'FR' => const [
          (group: VatGroup.standard, example: 'Prestations, boissons alcoolisées, sodas (taxe soda en sus)'),
          (group: VatGroup.intermediate, example: 'Repas et boissons sans alcool consommés sur place'),
          (group: VatGroup.reduced, example: 'Livres, boissons sans alcool à emporter, produits alimentaires'),
          (group: VatGroup.superReduced, example: 'Presse'),
          (group: VatGroup.excise, example: 'Bière, spiritueux : accises dans le prix, TVA 20 %'),
          (group: VatGroup.deposit, example: 'Consigne remboursable — hors champ de la TVA'),
          (group: VatGroup.exempt, example: 'Formation, opérations exonérées (art. 261 CGI)'),
          (group: VatGroup.notSubject, example: 'Association non assujettie (art. 293 B CGI)'),
        ],
      'DE' || 'AT' => const [
          (group: VatGroup.standard, example: 'Dienstleistungen, Getränke, Pfand (mit der Ware besteuert)'),
          (group: VatGroup.reduced, example: 'Bücher, Zeitungen, Lebensmittel zum Mitnehmen'),
          (group: VatGroup.excise, example: 'Bier, Spirituosen: Verbrauchsteuer im Preis, Regelsatz'),
          (group: VatGroup.exempt, example: 'Steuerfreie Umsätze (§ 4 UStG)'),
          (group: VatGroup.notSubject, example: 'Kleinunternehmer (§ 19 UStG)'),
        ],
      _ => const [
          (group: VatGroup.standard, example: 'Services, alcoholic and sugar drinks'),
          (group: VatGroup.reduced, example: 'Books, periodicals, food, non-alcoholic drinks'),
          (group: VatGroup.excise, example: 'Beer, spirits: excise inside the price, standard VAT'),
          (group: VatGroup.deposit, example: 'Refundable deposit'),
          (group: VatGroup.exempt, example: 'Exempt supplies'),
          (group: VatGroup.notSubject, example: 'Not subject to VAT'),
        ],
    };
