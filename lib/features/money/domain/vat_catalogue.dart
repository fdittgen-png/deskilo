// SPDX-License-Identifier: 0BSD
import 'vat_rate.dart';

/// The rates a country actually charges, so a workspace can start from its
/// own reality instead of typing percentages out of a tax leaflet (0072).
///
/// These are STARTING POINTS the owner then edits, not tax advice: rates
/// move, and which one applies to a given supply is a question for an
/// accountant. Only the standard rate is marked default — that is what
/// coworking membership normally falls under.
const Map<String, List<({String label, double percent})>> _catalogue = {
  'FR': [
    (label: 'Standard 20 %', percent: 20),
    (label: 'Intermédiaire 10 %', percent: 10),
    (label: 'Réduit 5,5 %', percent: 5.5),
  ],
  'DE': [
    (label: 'Regelsatz 19 %', percent: 19),
    (label: 'Ermäßigt 7 %', percent: 7),
  ],
  'ES': [
    (label: 'General 21 %', percent: 21),
    (label: 'Reducido 10 %', percent: 10),
    (label: 'Superreducido 4 %', percent: 4),
  ],
  'IT': [
    (label: 'Ordinaria 22 %', percent: 22),
    (label: 'Ridotta 10 %', percent: 10),
    (label: 'Ridotta 5 %', percent: 5),
  ],
  'BE': [
    (label: 'Standaard 21 %', percent: 21),
    (label: 'Verlaagd 12 %', percent: 12),
    (label: 'Verlaagd 6 %', percent: 6),
  ],
  'NL': [
    (label: 'Hoog 21 %', percent: 21),
    (label: 'Laag 9 %', percent: 9),
  ],
  'AT': [
    (label: 'Normalsatz 20 %', percent: 20),
    (label: 'Ermäßigt 10 %', percent: 10),
  ],
  'PT': [
    (label: 'Normal 23 %', percent: 23),
    (label: 'Intermédia 13 %', percent: 13),
    (label: 'Reduzida 6 %', percent: 6),
  ],
  'LU': [
    (label: 'Normal 17 %', percent: 17),
    (label: 'Réduit 8 %', percent: 8),
  ],
  'CH': [
    (label: 'Normal 8,1 %', percent: 8.1),
    (label: 'Réduit 2,6 %', percent: 2.6),
  ],
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
