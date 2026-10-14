// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 5 — FEC: DateLet accompanies every EcritureLet, and ValidDate of
// a recorded movement is the day it was recorded, not the day it happened.
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

List<Map<String, String>> _rows(List<LedgerEntry> ledger) {
  final lines = buildFecFile(
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    company: seededCompany,
    accounts: const FecAccounts(),
    lineText: (l) => l.label,
    ledger: ledger,
  ).split('\r\n');
  final head = lines.first.split('\t');
  return [
    for (final l in lines.skip(1)) Map.fromIterables(head, l.split('\t')),
  ];
}

void main() {
  test('every lettered row carries the date the lettering was completed', () {
    final rows = _rows(SeededExportYear.ledger);
    for (final r in rows) {
      expect(
        r['DateLet']!.isEmpty,
        r['EcritureLet']!.isEmpty,
        reason: '${r['EcritureNum']} letter ${r['EcritureLet']}',
      );
    }
    // INV-1: sold 5 March, settled 20 March.
    final inv1 = rows.where((r) => r['EcritureLet'] == 'INV-1');
    expect(inv1, isNotEmpty);
    expect(inv1.map((r) => r['DateLet']).toSet(), {'20260320'});
  });

  test('ValidDate of a ledger movement is the day it was recorded', () {
    final entry = LedgerEntry(
      id: 'L-late',
      memberId: 'm1',
      kind: LedgerKind.credit,
      category: LedgerCategory.expense,
      amountCents: 1000,
      description: 'Taxi',
      period: '2026-02',
      occurredOn: DateTime(2026, 2, 1),
      createdAt: DateTime(2026, 2, 10),
    );
    final row = _rows([entry]).firstWhere(
      (r) => r['EcritureNum'] == 'HA-L-late' && r['CompteNum'] == '606000',
    );
    expect(row['EcritureDate'], '20260201');
    expect(row['ValidDate'], '20260210');
  });
}
