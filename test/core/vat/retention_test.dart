// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the Dart clock answers the same day as `retention_until` (0480)
// for the same rule and document; the expected days are the ones pgTAP 223
// and the dev harness produced, written by hand from the statute rows.
import 'package:deskilo/core/vat/retention.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final set = ActiveTaxReference.current;

  DateTime until(String country, String docClass, DateTime on) =>
      retentionUntil(set.retentionOf(country, docClass)!, on);

  test('a UK invoice of 2023 is kept 6 years from the end of the year', () {
    expect(until('GB', 'invoice', DateTime.parse('2023-03-10')), DateTime.utc(2029, 12, 31));
  });

  test('DE: invoices 8 years, books 10 years', () {
    expect(until('DE', 'invoice', DateTime.parse('2017-05-01')), DateTime.utc(2025, 12, 31));
    expect(until('DE', 'books', DateTime.parse('2017-05-01')), DateTime.utc(2027, 12, 31));
  });

  test('CH keeps 10 years from the end of the financial year', () {
    expect(until('CH', 'invoice', DateTime.parse('2020-06-01')), DateTime.utc(2030, 12, 31));
  });

  test('the US default counts from the document day', () {
    expect(until('US', 'invoice', DateTime.parse('2020-06-01')), DateTime.parse('2024-06-01T00:00:00Z'));
  });

  test('a country without a row takes the shared rule; an unknown class has none', () {
    expect(until('ZZ', 'correspondence', DateTime.parse('2020-06-01')), DateTime.utc(2026, 12, 31));
    expect(set.retentionOf('GB', 'nope'), isNull);
  });

  test('a fiscal year opening in April ends the next 31 March', () {
    const rule = RetentionValue(years: 6, from: 'fiscal_year_end');
    expect(retentionUntil(rule, DateTime.parse('2023-02-01'), fiscalYearStartMonth: 4),
        DateTime.utc(2029, 3, 31));
    expect(retentionUntil(rule, DateTime.parse('2023-04-01'), fiscalYearStartMonth: 4),
        DateTime.utc(2030, 3, 31));
  });

  test('29 February lands on the 28th in a year without one', () {
    const rule = RetentionValue(years: 6, from: 'document_date');
    expect(retentionUntil(rule, DateTime.parse('2024-02-29')), DateTime.utc(2030, 2, 28));
  });

  test('the whole shipped table is unconfirmed and covers four classes everywhere', () {
    for (final row in set.rows.where((r) => r.domain == TaxDomain.retention)) {
      expect(row.confirmed, isFalse, reason: '${row.country}/${row.key}');
    }
    for (final c in ['DE', 'AT', 'CH', 'FR', 'GB', 'IE', 'CA', 'US', '*']) {
      for (final k in retentionClasses) {
        expect(set.where(TaxDomain.retention, country: c).any((r) => r.key == k), isTrue,
            reason: '$c/$k');
      }
    }
  });

  test('the archive notice states each period, the first free day and the status', () {
    final gb = retentionNotice('gb', 2026);
    expect(gb, contains('workspace country: GB'));
    expect(gb, contains('invoice: 6 years from the end of the fiscal year -> 2032-12-31 (not yet confirmed)'));
    expect(gb, contains('books: 6 years'));
    final de = retentionNotice('DE', 2026);
    expect(de, contains('invoice: 8 years from the end of the fiscal year -> 2034-12-31'));
    expect(de, contains('books: 10 years from the end of the fiscal year -> 2036-12-31'));
    final us = retentionNotice('US', 2026);
    expect(us, contains('invoice: 4 years from the document date -> 2030-12-31'));
  });

  test('the notice is the same bytes for the same inputs and names its statute', () {
    expect(retentionNotice('FR', 2025), retentionNotice('FR', 2025));
    expect(retentionNotice('FR', 2025), contains('source: Code de commerce L123-22'));
    // a country without rows of its own takes the shared rule
    expect(retentionNotice('ZZ', 2026), contains('invoice: 10 years'));
  });
}
