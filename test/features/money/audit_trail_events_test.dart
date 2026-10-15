// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 4 — the trail shows a write-off and a credit note's value.
import 'package:deskilo/features/money/domain/audit_trail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

void main() {
  final events = buildAuditEvents(
    invoices: SeededExportYear.invoices,
    matches: SeededExportYear.matches,
    ledger: SeededExportYear.ledger,
  );

  test(
    'a written-off invoice has a writeoff event for what was still owed',
    () {
      final writeoff = events.singleWhere((e) => e.kind == 'writeoff');
      expect(writeoff.reference, 'INV-3');
      expect(writeoff.at, DateTime(2026, 5, 25));
      expect(writeoff.amountCents, -4000);
    },
  );

  test('the credit note carries its signed value, not zero', () {
    final cn = events.singleWhere(
      (e) => e.kind == 'invoice' && e.reference == 'CN-1',
    );
    expect(cn.amountCents, -5000);
  });
}
