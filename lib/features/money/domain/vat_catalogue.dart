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

/// #2360/#2539 — a change of rate already decided: the successor version
/// of a `rate` row, dated in the future and CONFIRMED. While nobody has
/// confirmed it (the Swiss 2028 rates wait for the vote of 2026-11-29) it is a
/// proposal and nothing is returned; the platform administrator confirms or
/// withdraws it, and this reader follows the data -- no line of code flips.
PlannedRateChange? vatPlannedChangeFor(
  String countryCode,
  double percent, {
  String? asOf,
  DateTime? on,
  TaxReferenceSet? reference,
}) {
  final day = asOf ?? _dayOf(on) ?? (throw ArgumentError('a day (asOf or on) is required'));
  final set = reference ?? ActiveTaxReference.current;
  final country = countryCode.trim().toUpperCase();
  for (final now in set.ownRows(TaxDomain.rate, country, asOf: day)) {
    if (((now.value as RateValue).percent - percent).abs() > 1e-9) continue;
    final next = _successorOf(set, now, day);
    if (next == null || !next.confirmed) continue;
    return (
      from: next.validFrom,
      fromPercent: percent,
      toPercent: (next.value as RateValue).percent,
    );
  }
  return null;
}

/// The first version of [row]'s value that starts after [asOf].
TaxReferenceRow? _successorOf(TaxReferenceSet set, TaxReferenceRow row, String asOf) {
  TaxReferenceRow? next;
  for (final r in set.history(row.domain, row.country, row.key)) {
    if (r.validFrom.compareTo(asOf) > 0 &&
        (next == null || r.validFrom.compareTo(next.validFrom) < 0)) {
      next = r;
    }
  }
  return next;
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
}) {
  final day = asOf ?? _dayOf(on);
  final all = reference ?? ActiveTaxReference.current;
  final set = all.resolved(day);
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
  // #2360/#2539 — once a decided change of rate is in the data (a confirmed
  // successor version), the note says what to do.
  final decided = day != null &&
      all.ownRows(TaxDomain.rate, country, asOf: day).any((now) {
        final next = _successorOf(all, now, day);
        return next != null && next.confirmed;
      });
  final passed = decided ? text('note_vote_passed') : null;
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
