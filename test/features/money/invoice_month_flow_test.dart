// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- "Invoice the month" as a person meets it: the customers are
// ticked, one filled action issues them, the result page says what happened
// (and never claims an e-mail), what was refused stays listed with a retry
// for those only, and nothing breaks the experience rules at 320 and 390 px.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_month_flow.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../ux/experience_guards.dart';

const _entries = <ToInvoiceEntry>[
  (memberId: 'anna', name: 'Anna Alder', totalCents: 12000),
  (memberId: 'ben', name: 'Ben Birk', totalCents: 4550),
];

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  late FakeMoneyRepository repo;

  void charge(String member) => repo.ledger.add(
    LedgerEntry(
      id: 'l-$member',
      memberId: member,
      kind: LedgerKind.charge,
      category: LedgerCategory.service,
      amountCents: 450,
      description: 'Coffee',
      period: '2026-10',
      createdAt: DateTime(2026, 10),
    ),
  );

  setUp(() {
    repo = FakeMoneyRepository();
    charge('anna');
    charge('ben');
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    await pumpApp(
      tester,
      // The app's router keeps the auth stream alive; here a watcher does.
      Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return const InvoiceMonthFlow(
            period: '2026-10',
            entries: _entries,
            currency: 'EUR',
            workspaceId: 'ws-1',
          );
        },
      ),
      size: size,
      overrides: standardTestOverrides(
        money: repo,
        auth: FakeAuthRepository.signedIn(),
        workspace: FakeWorkspaceRepository.withWorkspace(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every customer is ticked; the one filled action says how many', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.text('Ben Birk'), findsOneWidget);
    expect(find.text('Issue 2 invoices'), findsOneWidget);
    expect(find.textContaining('2 CUSTOMERS'), findsOneWidget);
    expect(
      find.textContaining('can no longer be edited'),
      findsOneWidget,
      reason: 'the rule is said before issuing',
    );
    await tester.tap(_key('invoice-month-select-ben'));
    await tester.pumpAndSettle();
    expect(find.text('Issue 1 invoice'), findsOneWidget);
    expect(find.textContaining('1 CUSTOMER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issuing ends on a result page that claims no e-mail', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await tester.pumpAndSettle();
    expect(find.text('2 invoices issued'), findsOneWidget);
    expect(find.text('Issued'), findsNWidgets(2));
    expect(
      find.text(
        'Each customer sees it in their account now and gets a notification.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('e-mail'), findsNothing);
    expect(find.textContaining('sent'), findsNothing);
    expect(repo.invoices, hasLength(2));
    expect(_key('invoice-month-retry'), findsNothing);
  });

  testWidgets('a customer the server refused stays listed with a retry for '
      'those only', (tester) async {
    // Anna is invoiced for October already: the server refuses her alone.
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: '2026-10',
    );
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await tester.pumpAndSettle();
    expect(find.text('1 invoice issued'), findsOneWidget);
    expect(find.text('Not done'), findsOneWidget);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.text('Ben Birk'), findsOneWidget);
    expect(find.text('What was not done stays in To do.'), findsOneWidget);
    expect(_key('invoice-month-retry'), findsOneWidget);
    expect(find.text('Retry for these'), findsOneWidget);
    expect(repo.invoices, hasLength(2), reason: 'only Ben was added');
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('review and result keep the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await loadSheetFonts();
      await pump(tester, size: Size(width, 3000));
      expect(guardProblems(tester, width: width), isEmpty);
      await tester.tap(_key('invoice-month-issue'));
      await tester.pumpAndSettle();
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }

  // The pictures a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: the review list and the result', (tester) async {
    await loadSheetFonts();
    await pump(tester);
    await writeSheet(tester, sheet: 'invoice-month', name: 'review');
    await tester.tap(_key('invoice-month-issue'));
    await tester.pumpAndSettle();
    await writeSheet(tester, sheet: 'invoice-month', name: 'result');
  });

  testWidgets('sheet: a result with one customer not done', (tester) async {
    await loadSheetFonts();
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: '2026-10',
    );
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await tester.pumpAndSettle();
    await writeSheet(tester, sheet: 'invoice-month', name: 'result-not-done');
  });
}
