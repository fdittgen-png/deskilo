// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 2 — a file for one fiscal year carries that year's books only.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/export_year.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

void main() {
  test('the scope keeps the year of the export, whole', () {
    final scope = exportYearScope(
      2026,
      invoices: SeededExportYear.invoices,
      ledger: SeededExportYear.ledger,
      repartitions: SeededExportYear.repartitions,
    );
    expect(scope.invoices, hasLength(4));
    expect(scope.ledger.map((e) => e.id), ['L-exp-2026', 'L-pay-2026']);
    expect(scope.repartitions, isEmpty);
    final other = exportYearScope(
      2025,
      invoices: SeededExportYear.invoices,
      ledger: SeededExportYear.ledger,
      repartitions: SeededExportYear.repartitions,
    );
    expect(other.invoices, isEmpty);
    expect(other.repartitions.single.id, 'R-2025');
  });

  test('DATEV of the scoped books never re-dates another year', () {
    final scope = exportYearScope(
      2026,
      invoices: SeededExportYear.invoices,
      ledger: SeededExportYear.ledger,
      repartitions: SeededExportYear.repartitions,
    );
    final file = buildDatevFile(
      invoices: scope.invoices,
      matches: SeededExportYear.matches,
      accounts: const DatevAccounts(),
      from: DateTime(2026),
      to: DateTime(2026, 12, 31),
      generatedAt: DateTime(2027, 1, 5),
      consultantNumber: '1001',
      clientNumber: '20002',
      ledger: scope.ledger,
      repartitions: scope.repartitions,
    );
    expect(file, isNot(contains('L-exp-2024')));
    expect(file, isNot(contains('R-2025')));
    expect(file, contains('L-exp-2026'));
  });

  test('the FEC of the scoped books holds no entry of another year', () {
    final scope = exportYearScope(
      2026,
      invoices: SeededExportYear.invoices,
      ledger: SeededExportYear.ledger,
      repartitions: SeededExportYear.repartitions,
    );
    final file = buildFecFile(FecRequest(
      invoices: scope.invoices,
      matches: SeededExportYear.matches,
      company: seededCompany,
      accounts: const FecAccounts(),
      lineText: (l) => l.label,
      ledger: scope.ledger,
      repartitions: scope.repartitions,
    ));
    expect(file, isNot(contains('L-exp-2024')));
    expect(file, isNot(contains('R-2025')));
    expect(file, contains('L-exp-2026'));
  });
}
