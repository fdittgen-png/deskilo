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
const Map<String, List<({String label, double percent})>> _catalogue = {
  // ── EU 27 ──────────────────────────────────────────────────────────
  'AT': [
    (label: 'Normalsatz 20 %', percent: 20),
    (label: 'Ermäßigt 13 %', percent: 13),
    (label: 'Ermäßigt 10 %', percent: 10),
  ],
  'BE': [
    (label: 'Standaard 21 %', percent: 21),
    (label: 'Verlaagd 12 %', percent: 12),
    (label: 'Verlaagd 6 %', percent: 6),
  ],
  'BG': [
    (label: 'Стандартна 20 %', percent: 20),
    (label: 'Намалена 9 %', percent: 9),
  ],
  'HR': [
    (label: 'Standardna 25 %', percent: 25),
    (label: 'Snižena 13 %', percent: 13),
    (label: 'Snižena 5 %', percent: 5),
  ],
  'CY': [
    (label: 'Standard 19 %', percent: 19),
    (label: 'Reduced 9 %', percent: 9),
    (label: 'Reduced 5 %', percent: 5),
  ],
  'CZ': [
    (label: 'Základní 21 %', percent: 21),
    (label: 'Snížená 12 %', percent: 12),
  ],
  'DK': [
    (label: 'Standard 25 %', percent: 25),
  ],
  'EE': [
    (label: 'Standardmäär 24 %', percent: 24),
    (label: 'Vähendatud 13 %', percent: 13),
    (label: 'Vähendatud 9 %', percent: 9),
  ],
  'FI': [
    (label: 'Yleinen 25,5 %', percent: 25.5),
    (label: 'Alennettu 13,5 %', percent: 13.5),
    (label: 'Alennettu 10 %', percent: 10),
  ],
  'FR': [
    (label: 'Standard 20 %', percent: 20),
    (label: 'Intermédiaire 10 %', percent: 10),
    (label: 'Réduit 5,5 %', percent: 5.5),
    (label: 'Particulier 2,1 %', percent: 2.1),
  ],
  'DE': [
    (label: 'Regelsatz 19 %', percent: 19),
    (label: 'Ermäßigt 7 %', percent: 7),
  ],
  'GR': [
    (label: 'Κανονικός 24 %', percent: 24),
    (label: 'Μειωμένος 13 %', percent: 13),
    (label: 'Μειωμένος 6 %', percent: 6),
  ],
  'HU': [
    (label: 'Általános 27 %', percent: 27),
    (label: 'Kedvezményes 18 %', percent: 18),
    (label: 'Kedvezményes 5 %', percent: 5),
  ],
  'IE': [
    (label: 'Standard 23 %', percent: 23),
    (label: 'Reduced 13.5 %', percent: 13.5),
    (label: 'Reduced 9 %', percent: 9),
    (label: 'Livestock 4.8 %', percent: 4.8),
  ],
  'IT': [
    (label: 'Ordinaria 22 %', percent: 22),
    (label: 'Ridotta 10 %', percent: 10),
    (label: 'Ridotta 5 %', percent: 5),
    (label: 'Minima 4 %', percent: 4),
  ],
  'LV': [
    (label: 'Standarta 21 %', percent: 21),
    (label: 'Samazinātā 12 %', percent: 12),
    (label: 'Samazinātā 5 %', percent: 5),
  ],
  'LT': [
    (label: 'Standartinis 21 %', percent: 21),
    (label: 'Lengvatinis 9 %', percent: 9),
    (label: 'Lengvatinis 5 %', percent: 5),
  ],
  'LU': [
    (label: 'Normal 17 %', percent: 17),
    (label: 'Intermédiaire 14 %', percent: 14),
    (label: 'Réduit 8 %', percent: 8),
    (label: 'Super-réduit 3 %', percent: 3),
  ],
  'MT': [
    (label: 'Standard 18 %', percent: 18),
    (label: 'Reduced 7 %', percent: 7),
    (label: 'Reduced 5 %', percent: 5),
  ],
  'NL': [
    (label: 'Hoog 21 %', percent: 21),
    (label: 'Laag 9 %', percent: 9),
  ],
  'PL': [
    (label: 'Podstawowa 23 %', percent: 23),
    (label: 'Obniżona 8 %', percent: 8),
    (label: 'Obniżona 5 %', percent: 5),
  ],
  'PT': [
    (label: 'Normal 23 %', percent: 23),
    (label: 'Intermédia 13 %', percent: 13),
    (label: 'Reduzida 6 %', percent: 6),
  ],
  'RO': [
    (label: 'Standard 21 %', percent: 21),
    (label: 'Redusă 11 %', percent: 11),
  ],
  'SK': [
    (label: 'Základná 23 %', percent: 23),
    (label: 'Znížená 19 %', percent: 19),
    (label: 'Znížená 5 %', percent: 5),
  ],
  'SI': [
    (label: 'Splošna 22 %', percent: 22),
    (label: 'Znižana 9,5 %', percent: 9.5),
    (label: 'Znižana 5 %', percent: 5),
  ],
  'ES': [
    (label: 'General 21 %', percent: 21),
    (label: 'Reducido 10 %', percent: 10),
    (label: 'Superreducido 4 %', percent: 4),
  ],
  'SE': [
    (label: 'Standard 25 %', percent: 25),
    (label: 'Reducerad 12 %', percent: 12),
    (label: 'Reducerad 6 %', percent: 6),
  ],
  // ── Non-EU Europe ──────────────────────────────────────────────────
  'CH': [
    (label: 'Normal 8,1 %', percent: 8.1),
    (label: 'Hébergement 3,8 %', percent: 3.8),
    (label: 'Réduit 2,6 %', percent: 2.6),
  ],
  'NO': [
    (label: 'Alminnelig 25 %', percent: 25),
    (label: 'Næringsmidler 15 %', percent: 15),
    (label: 'Redusert 12 %', percent: 12),
  ],
  // ── North America ──────────────────────────────────────────────────
  // Canada: GST is federal; the usable rate depends on the PROVINCE, so
  // the catalogue lists the per-province combined realities. The owner
  // keeps the one that applies and deletes the rest.
  'CA': [
    (label: 'GST 5 % (AB/NT/NU/YT)', percent: 5),
    (label: 'HST 13 % (ON)', percent: 13),
    (label: 'HST 14 % (NS)', percent: 14),
    (label: 'HST 15 % (NB/NL/PE)', percent: 15),
    (label: 'GST+QST 14,975 % (QC)', percent: 14.975),
    (label: 'GST+PST 12 % (BC/MB)', percent: 12),
    (label: 'GST+PST 11 % (SK)', percent: 11),
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
List<VatRate> vatCatalogueFor(String countryCode) => [
      for (final (index, rate)
          in (_catalogue[countryCode.toUpperCase()] ?? const []).indexed)
        VatRate(
          label: rate.label,
          percent: rate.percent,
          isDefault: index == 0,
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
