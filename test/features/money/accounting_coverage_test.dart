// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the coverage table in docs/domain/ACCOUNTING_EXPORTS.md is the
// registry's: a target added, moved or requalified without regenerating it
// fails here (`dart run tool/build_accounting_coverage.dart`).
import 'dart:io';

import 'package:deskilo/features/money/domain/accounting_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the document carries the registry as it is', () {
    final doc = File('docs/domain/ACCOUNTING_EXPORTS.md').readAsStringSync();
    expect(
      withAccountingCoverage(doc),
      doc,
      reason: 'run dart run tool/build_accounting_coverage.dart',
    );
  });

  test('every target has its row', () {
    final table = accountingCoverageTable();
    for (final id in ['fec', 'datev', 'generic_journal_csv', 'bundle']) {
      expect(table, contains('| `$id` |'));
    }
  });
}
