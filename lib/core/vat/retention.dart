// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the retention clock. The rules are `retention` rows of the tax
// reference store (one per country and document class); this is the Dart twin
// of `retention_until` (0480): the first day a record may go.
import 'package:meta/meta.dart';

import '../time/date_text.dart';
import 'tax_reference.dart';
import 'tax_reference_active.dart';

/// The document classes a retention rule is kept for.
const retentionClasses = ['invoice', 'books', 'correspondence', 'voucher'];

extension RetentionQueries on TaxReferenceSet {
  /// The row (value, source, confirmed) behind [retentionOf].
  TaxReferenceRow? retentionRowOf(String country, String docClass, {String? asOf}) =>
      resolved(asOf).lookup(TaxDomain.retention, country, docClass);

  /// The rule for [docClass] in [country], the shared `*` rule where the
  /// country has none; null for a class nobody listed.
  RetentionValue? retentionOf(String country, String docClass, {String? asOf}) =>
      resolved(asOf).lookup(TaxDomain.retention, country, docClass)?.value
          as RetentionValue?;
}

/// The first day a document dated [documentDate] may go under [rule]. The
/// clock starts at the end of the fiscal year the document falls in -- the
/// year opening on [fiscalYearStartMonth]/[fiscalYearStartDay], the calendar
/// year by default -- or at the document's own day.
@visibleForTesting
DateTime retentionUntil(
  RetentionValue rule,
  DateTime documentDate, {
  int fiscalYearStartMonth = 1,
  int fiscalYearStartDay = 1,
}) {
  final doc = DateTime.utc(documentDate.year, documentDate.month, documentDate.day);
  DateTime base;
  if (rule.from == 'document_date') {
    base = doc;
  } else {
    DateTime opening(int year) {
      final last = DateTime.utc(year, fiscalYearStartMonth + 1, 0).day;
      return DateTime.utc(
          year, fiscalYearStartMonth, fiscalYearStartDay > last ? last : fiscalYearStartDay);
    }

    var start = opening(doc.year);
    if (start.isAfter(doc)) start = opening(doc.year - 1);
    base = DateTime.utc(start.year + 1, start.month, start.day - 1);
  }
  final year = base.year + rule.years;
  // 29 February in a year without one lands on the 28th, as the database does.
  final last = DateTime.utc(year, base.month + 1, 0).day;
  return DateTime.utc(year, base.month, base.day > last ? last : base.day);
}

/// The first day a document dated [documentDate] may go under [rule], the
/// fiscal year opening on [fiscalYearStart]'s month and day.
DateTime retentionRuleUntil(
  RetentionRule rule,
  DateTime documentDate, {
  DateTime? fiscalYearStart,
}) => retentionUntil(
  RetentionValue(years: rule.years, from: rule.from),
  documentDate,
  fiscalYearStartMonth: fiscalYearStart?.month ?? 1,
  fiscalYearStartDay: fiscalYearStart?.day ?? 1,
);

/// #2571 — one rule of [country] as the tax reference holds it.
/// [bySetting]: the space's own longer period (`retention.us_years`) stands
/// in for the row, as `retention_rule_for` does.
typedef RetentionRule = ({
  String docClass,
  int years,
  String from,
  bool confirmed,
  String source,
  bool bySetting,
});

/// The country whose spaces may extend the rule with `retention.us_years`.
const _usYearsCountry = 'US';

/// True when a space of [country] may extend its rules with its own
/// `retention.us_years`.
bool retentionExtendsBySetting(String country) => country.trim().toUpperCase() == _usYearsCountry;

/// The rules in force for [country] (the shared rule where it has none),
/// one per document class that has one, in class order. A US space's
/// [usYears] replaces a SHORTER rule and never a longer one.
List<RetentionRule> retentionRules(String country, {TaxReferenceSet? reference, int usYears = 0}) {
  final set = reference ?? ActiveTaxReference.current;
  final extends_ = retentionExtendsBySetting(country);
  return [
    for (final docClass in retentionClasses)
      if (set.retentionRowOf(country, docClass) case final row?)
        if (extends_ && usYears > (row.value as RetentionValue).years)
          (
            docClass: docClass,
            years: usYears,
            from: 'document_date',
            confirmed: row.confirmed,
            source: row.source,
            bySetting: true,
          )
        else
          (
            docClass: docClass,
            years: (row.value as RetentionValue).years,
            from: (row.value as RetentionValue).from,
            confirmed: row.confirmed,
            source: row.source,
            bySetting: false,
          ),
  ];
}

/// #2571 — the retention rules of [country] in words, for the archive of
/// fiscal year [year]: per document class the period, where the clock
/// starts, the first day a document of that year may go, the statute and
/// whether a person has confirmed the rule. Plain text, no timestamp: the
/// same inputs are the same bytes. A class with no rule is absent.
String retentionNotice(String country, int year, {TaxReferenceSet? reference}) {
  final set = reference ?? ActiveTaxReference.current;
  final lines = [
    'Record retention for the fiscal year $year (workspace country: ${country.toUpperCase()}).',
    'Dates are the first day a document dated 31 December $year may be erased.',
    '',
  ];
  for (final docClass in retentionClasses) {
    final row = set.retentionRowOf(country, docClass);
    if (row == null) continue;
    final rule = row.value as RetentionValue;
    lines
      ..add('$docClass: ${rule.years} years from '
          '${rule.from == 'document_date' ? 'the document date' : 'the end of the fiscal year'}'
          ' -> ${isoDay(retentionUntil(rule, DateTime(year, 12, 31)))}'
          '${row.confirmed ? '' : ' (not yet confirmed)'}')
      ..add('  source: ${row.source}');
  }
  return '${lines.join('\r\n')}\r\n';
}
