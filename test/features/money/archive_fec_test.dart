// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2376 — the year archive's FEC: a closed fiscal year's FEC is final,
// logged once and carried with the same bytes ever after; an open year's
// is provisional, under a name that says so; the qualification lives in
// the manifest, never inside the FEC; a non-French archive has none.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/archive_fec.dart';
import 'package:deskilo/features/money/domain/book_period.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/fec_import_contract.dart';
import 'package:deskilo/features/money/domain/fiscal_year.dart';
import 'package:flutter_test/flutter_test.dart';

final _year = FiscalYear(DateTime(2025, 10), DateTime(2026, 9, 30));
const _name = '812345678FEC20260930.txt';
final _fec = '${fecColumns.join('\t')}\r\n';
String _sha(String s) => sha256.convert(utf8.encode(s)).toString();

BookExport _logged(String sha, {bool closed = true, FiscalYear? year}) =>
    BookExport(
      id: 'e1',
      formatId: archiveFecFormatId,
      from: (year ?? _year).from,
      to: (year ?? _year).to,
      sha256: sha,
      byteCount: 1,
      rowCount: 1,
      documentCount: 0,
      closedPeriod: closed,
      exportedAt: DateTime.utc(2026, 10, 15),
    );

ArchiveFecPlan _plan({
  required bool closed,
  List<BookExport> exports = const [],
}) => archiveFecPlan(
  fec: _fec,
  fileName: _name,
  year: _year,
  closed: closed,
  exports: exports,
  contract: const FecContractReport([], records: 0),
);

BookPeriod _period(DateTime from, DateTime to) => BookPeriod(
  id: '${from.month}',
  from: from,
  to: to,
  reason: BookPeriodReason.owner,
);

void main() {
  test('a closed year\'s FEC is final, under its own name, logged now', () {
    final plan = _plan(closed: true) as ArchiveFecWrite;
    expect(plan.members.keys, unorderedEquals([_name, 'fec-manifest.txt']));
    expect(utf8.decode(plan.members[_name]!), _fec);
    expect(plan.logNow, isTrue);
    expect(plan.sha256, _sha(_fec));
    final manifest = utf8.decode(plan.members['fec-manifest.txt']!);
    expect(manifest, contains('status: final'));
    expect(manifest, contains('fiscal_year: 2025-10-01..2026-09-30'));
    expect(manifest, contains('sha256: ${_sha(_fec)}'));
    expect(manifest, contains('scope: the entries DesKilo posts'));
  });

  test('a second archive of the closed year carries the logged bytes and '
      'logs nothing', () {
    final plan =
        _plan(closed: true, exports: [_logged(_sha(_fec))]) as ArchiveFecWrite;
    expect(plan.logNow, isFalse);
    expect(
      utf8.decode(plan.members['fec-manifest.txt']!),
      contains('logged: 2026-10-15'),
    );
  });

  test('a closed year whose FEC changed since it was logged is refused', () {
    final plan = _plan(closed: true, exports: [_logged('0' * 64)]);
    expect(plan, isA<ArchiveFecChanged>());
    expect(
      (plan as ArchiveFecChanged).logged.exportedAt,
      DateTime.utc(2026, 10, 15),
    );
  });

  test('a log of another period, or of an open one, is not the final FEC', () {
    for (final other in [
      _logged('0' * 64, closed: false),
      _logged('0' * 64, year: FiscalYear.calendar(2026)),
    ]) {
      expect(_plan(closed: true, exports: [other]), isA<ArchiveFecWrite>());
    }
  });

  test('an open year\'s FEC is provisional, named so, never logged', () {
    final plan = _plan(closed: false) as ArchiveFecWrite;
    expect(plan.members.keys, contains('PROVISOIRE-$_name'));
    expect(plan.members.keys, isNot(contains(_name)));
    expect(plan.logNow, isFalse);
    final manifest = utf8.decode(plan.members['fec-manifest.txt']!);
    expect(manifest, contains('status: provisional'));
    // The FEC itself starts with its header, qualification or not.
    expect(
      utf8.decode(plan.members['PROVISOIRE-$_name']!),
      startsWith('JournalCode\t'),
    );
  });

  test('the manifest quotes a failed import contract', () {
    final plan = archiveFecPlan(
      fec: _fec,
      fileName: _name,
      year: _year,
      closed: false,
      exports: const [],
      contract: const FecContractReport([
        FecFinding(FecRule.balance, 2, 'off'),
      ], records: 1),
    ) as ArchiveFecWrite;
    expect(
      utf8.decode(plan.members['fec-manifest.txt']!),
      contains('import_contract: failed (balance), 1 records'),
    );
  });

  test('only a French archive carries the FEC members', () {
    final members = (_plan(closed: true) as ArchiveFecWrite).members;
    for (final (country, has) in [('FR', true), ('DE', false)]) {
      final files = <String, List<int>>{};
      addArchiveFec(files, country, members);
      expect(files.containsKey(_name), has, reason: country);
    }
  });

  group('the fiscal year', () {
    test('is closed only when every day lies in a closed period', () {
      final halves = BookPeriodsOverview(
        periods: [
          _period(DateTime(2025, 10), DateTime(2026, 3, 31)),
          _period(DateTime(2026, 4), DateTime(2026, 9, 30)),
        ],
      );
      expect(fiscalYearClosed(halves, _year), isTrue);
      final gap = BookPeriodsOverview(
        periods: [_period(DateTime(2025, 10), DateTime(2026, 9, 29))],
      );
      expect(fiscalYearClosed(gap, _year), isFalse);
      expect(fiscalYearClosed(const BookPeriodsOverview(), _year), isFalse);
    });

    test('holds its first and last day only', () {
      expect(
        FiscalYear.calendar(2026),
        FiscalYear(DateTime(2026), DateTime(2026, 12, 31)),
      );
      expect(_year.contains(DateTime(2026, 9, 30)), isTrue);
      expect(_year.contains(DateTime(2026, 10)), isFalse);
    });
  });
}
