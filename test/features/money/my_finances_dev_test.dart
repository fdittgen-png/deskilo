// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: Me is production. A development space's documents are test
// data — never in a total, listed apart, in the development colour, with DEV
// beside the space's name — and an invoice opens in its own environment.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'my_finances_screen_test.dart' show invoice, show;

FakeWorkspaceRepository _spaces() {
  final repo = FakeWorkspaceRepository.withWorkspace();
  final base = repo.workspaces.first;
  repo.workspaces
    ..clear()
    ..add(
      base.copyWith(id: 'ws-Office A', name: 'Office A', environment: 'prod'),
    )
    ..add(base.copyWith(id: 'ws-Lab', name: 'Lab', environment: 'dev'));
  return repo;
}

void main() {
  test('production and development split, reminders follow their invoice', () {
    final o = FinanceOverview(
      invoices: [
        invoice('p', ws: 'Office A'),
        invoice('d', ws: 'Lab'),
      ],
      reminders: [
        FinanceReminder(
          id: 'r',
          invoiceId: 'd',
          invoiceNumber: 'INV-d',
          workspaceName: 'Lab',
          sentAt: DateTime.utc(2026, 9, 2),
          level: 1,
          automatic: false,
        ),
      ],
    );
    final prod = o.production({'ws-Lab'});
    expect(prod.invoices.map((i) => i.id), ['p']);
    expect(prod.reminders, isEmpty);
    expect(o.development({'ws-Lab'}).reminders.single.id, 'r');
  });

  testWidgets('a development invoice is never counted and wears DEV', (
    tester,
  ) async {
    await show(
      tester,
      FinanceOverview(
        invoices: [
          invoice('p', ws: 'Office A', total: 10000),
          invoice('d', ws: 'Lab', total: 99900),
        ],
      ),
      workspace: _spaces(),
    );
    // The total is production only.
    final summary = find.byKey(const ValueKey('finances-summary'));
    expect(
      find.descendant(of: summary, matching: find.textContaining('100')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summary, matching: find.textContaining('999')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('finances-dev-section')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finances-invoice-d')),
        matching: find.byKey(const ValueKey('dev-label-chip')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finances-invoice-p')),
        matching: find.byKey(const ValueKey('dev-label-chip')),
      ),
      findsNothing,
    );
    // The summary sits above the development section.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('finances-summary'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('finances-dev-section')))
            .dy,
      ),
    );
  });
}
