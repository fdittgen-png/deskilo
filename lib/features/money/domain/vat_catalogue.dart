// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/time/date_text.dart';
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'vat_rate.dart';

// #2478 (C2 of #2476) — the rates a country actually charges, so a
// workspace can start from its own reality instead of typing percentages
// out of a tax leaflet (0072, expanded #534 to every EU member state,
// Switzerland, Norway, the United Kingdom and the Canadian provinces), are
// ROWS of the tax reference store (`rate`, `catalogue_note`,
// `group_example`), each with its source and a `confirmed` flag. Nothing of
// them is written in code: this file only assembles the rows into the
// editable [VatRate]s the seed button offers.
//
// They are STARTING POINTS the owner then edits, not tax advice: rates
// move, and which one applies to a given supply is a question for an
// accountant. Only the first rate (the standard one) is marked default.

/// #2360 — a change of rate already decided or proposed: the new value
/// from a date, applied by the owner's "change by law" (a successor
/// version linked to the old one, so items follow the family).
typedef PlannedRateChange = ({
  String from,
  double fromPercent,
  double toPercent,
});

/// #2360 — Switzerland, 13th AHV pension: normal rate 8.1 -> 8.5 % and
/// the accommodation rate 3.8 -> 4.0 % from 2028-01-01; the reduced rate
/// 2.6 % is not touched. The popular vote is on 2026-11-29: ONE LINE
/// activates it, set this to true when the people have said yes.
const bool _swissReform2028Approved = false;

const Map<String, List<PlannedRateChange>> _plannedChanges = {
  'CH': [
    (from: '2028-01-01', fromPercent: 8.1, toPercent: 8.5),
    (from: '2028-01-01', fromPercent: 3.8, toPercent: 4.0),
  ],
};

/// The change planned for a rate of [percent], once decided (nothing
/// while the Swiss vote has not passed; [approved] overrides for tests).
PlannedRateChange? vatPlannedChangeFor(String countryCode, double percent,
    {bool approved = _swissReform2028Approved}) {
  if (countryCode.toUpperCase() == 'CH' && !approved) return null;
  for (final c in _plannedChanges[countryCode.toUpperCase()] ?? <PlannedRateChange>[]) {
    if (c.fromPercent == percent) return c;
  }
  return null;
}

/// The ISO day of [on], null while no day is given (the newest versions).
String? _dayOf(DateTime? on) => on == null ? null : isoDay(on);

/// Every country the catalogue knows.
Iterable<String> get vatCatalogueCountries => {
      for (final row in ActiveTaxReference.current.where(TaxDomain.rate))
        row.country,
    }.toList()
      ..sort();

/// The country's usual rates as editable [VatRate]s, standard first and
/// marked as the default: the versions in force on [asOf] (the newest ones
/// without it), in the order of their `position`.
List<VatRate> vatCatalogueFor(
  String countryCode, {
  String? asOf,
  DateTime? on,
  TaxReferenceSet? reference,
}) {
  final rows = (reference ?? ActiveTaxReference.current)
      .ownRows(TaxDomain.rate, countryCode, asOf: asOf ?? _dayOf(on))
    ..sort((a, b) => (a.value as RateValue)
        .position
        .compareTo((b.value as RateValue).position));
  return [
    for (final (index, row) in rows.indexed)
      _vatRateOf(row.value as RateValue, row.validFrom, isDefault: index == 0),
  ];
}

VatRate _vatRateOf(RateValue v, String validFrom, {required bool isDefault}) {
  final group = VatGroup.fromWire(v.group);
  return VatRate(
    label: v.label,
    percent: v.percent,
    isDefault: isDefault,
    // #985 — the group is the catalogue's, not a guess from the number.
    category: v.category,
    groupKey: group.wire,
    outsideBase: group.outsideBase,
    validFrom: validFrom,
    exemptionReason: v.exemptionReason,
  );
}

/// A short country-specific caveat shown next to the seed button (#534):
/// the moments where "here are your country's rates" needs an asterisk.
String? vatCatalogueNote(
  String countryCode, {
  String? asOf,
  DateTime? on,
  TaxReferenceSet? reference,
  bool reformApproved = _swissReform2028Approved,
}) {
  final set = (reference ?? ActiveTaxReference.current).resolved(asOf ?? _dayOf(on));
  final country = countryCode.trim().toUpperCase();
  String? text(String key) {
    for (final row in set.where(TaxDomain.catalogueNote, country: country)) {
      if (row.country == country && row.key == key) {
        return (row.value as CatalogueNoteValue).text;
      }
    }
    return null;
  }

  final note = text('note');
  if (note == null) return null;
  // #2360 — once the Swiss vote has passed, the note says what to do.
  final passed = reformApproved ? text('note_vote_passed') : null;
  return passed == null ? note : '$note $passed';
}

/// #947 — what falls in each group, country by country: starting points
/// for the owner, not tax advice. A country with no entry gets the
/// EU-wide shape (the `*` rows).
List<({VatGroup group, String example})> vatGroupExamples(
  String countryCode, {
  String? asOf,
  TaxReferenceSet? reference,
}) {
  final set = (reference ?? ActiveTaxReference.current).resolved(asOf);
  final own = set.ownRows(TaxDomain.groupExample, countryCode);
  final rows = own.isNotEmpty
      ? own
      : [
          for (final row in set.rows)
            if (row.domain == TaxDomain.groupExample &&
                row.country == taxReferenceAnyCountry)
              row,
        ];
  final ordered = [...rows]..sort((a, b) => (a.value as GroupExampleValue)
      .position
      .compareTo((b.value as GroupExampleValue).position));
  return [
    for (final row in ordered)
      (
        group: VatGroup.fromWire((row.value as GroupExampleValue).group),
        example: (row.value as GroupExampleValue).text,
      ),
  ];
}
