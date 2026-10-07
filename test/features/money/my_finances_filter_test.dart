// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant (ADR 0035): the documents of several workspaces arrive in Me ›
// Finances together, and a workspace links there already narrowed to itself.
// "All spaces" widens it again; another space's documents never show under a
// filter; reminders follow their invoice.
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'my_finances_screen_test.dart' show invoice, show;

FinanceOverview _two() => FinanceOverview(
  invoices: [
    invoice('a', ws: 'Office A'),
    invoice('b', ws: 'Office B'),
  ],
  reminders: [
    FinanceReminder(
      id: 'r-b',
      invoiceId: 'b',
      invoiceNumber: 'INV-b',
      workspaceName: 'Office B',
      sentAt: DateTime.utc(2026, 9, 20),
      level: 1,
      automatic: true,
    ),
  ],
);

void main() {
  test('inWorkspace keeps one space and the reminders of its invoices', () {
    final only = _two().inWorkspace('ws-Office B');
    expect(only.invoices.map((i) => i.id), ['b']);
    expect(only.reminders.map((r) => r.id), ['r-b']);
    expect(_two().inWorkspace('ws-Office A').reminders, isEmpty);
    expect(_two().inWorkspace(null).invoices, hasLength(2));
  });

  testWidgets('opened for one workspace, only its documents show; All spaces '
      'brings the rest back', (tester) async {
    await show(tester, _two(), workspaceId: 'ws-Office B');
    expect(find.byKey(const ValueKey('finances-invoice-b')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-a')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('finances-filter-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-invoice-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('finances-invoice-b')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finances-filter-ws-Office A')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('finances-invoice-b')), findsNothing);
  });

  testWidgets('with one workspace only there is no filter to show', (
    tester,
  ) async {
    await show(tester, FinanceOverview(invoices: [invoice('a')]));
    expect(find.byKey(const ValueKey('finances-filter')), findsNothing);
  });
}
