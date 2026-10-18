// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the retention clock. The rules are `retention` rows of the tax
// reference store (one per country and document class); this is the Dart twin
// of `retention_until` (0479): the first day a record may go.
import 'tax_reference.dart';
import 'tax_reference_active.dart';

/// The document classes a retention rule is kept for.
const retentionClasses = ['invoice', 'books', 'correspondence', 'voucher'];

extension RetentionQueries on TaxReferenceSet {
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
