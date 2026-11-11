// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- "Invoice the month" as a person meets it: the customers are
// read first and ticked, one filled action issues them, a customer with a gap
// cannot be issued until it is fixed, a gap of the business is said once, the
// result page says what happened (never an e-mail) and what was refused stays
// listed with a retry for those only; no rule of the experience breaks at 320
// and 390 px.
import 'dart:async';

import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/money/application/issue_invoice.dart';
import 'package:deskilo/features/money/application/issue_month.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_month_flow.dart';
import 'package:deskilo/features/money/presentation/invoicing/invoice_month_result.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
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

/// Lets the flow's reads and writes finish.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

/// The money fake whose dry run says what the test set.
class _Repo extends FakeMoneyRepository {
  final Map<String, List<String>> missing = {};
  final Set<String> failing = {};

  /// A read held until the test lets it answer.
  final Map<String, Completer<void>> held = {};

  @override
  Future<List<String>> invoiceIssueReadiness({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async {
    await held[memberId]?.future;
    if (failing.contains(memberId)) throw StateError('offline');
    return missing[memberId] ?? const [];
  }
}

void main() {
  late _Repo repo;
  final fixedCustomers = <String>[];
  var fixedBusiness = 0;

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
    repo = _Repo();
    fixedCustomers.clear();
    fixedBusiness = 0;
    charge('anna');
    charge('ben');
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Future<void> Function(String memberId)? onFixCustomer,
    Future<void> Function()? onFixBusiness,
  }) async {
    await pumpApp(
      tester,
      // The app's router keeps the auth stream alive; here a watcher does.
      Consumer(
        builder: (context, ref, _) {
          ref.watch(authStateProvider);
          return InvoiceMonthFlow(
            period: '2026-10',
            entries: _entries,
            currency: 'EUR',
            workspaceId: 'ws-1',
            onFixCustomer:
                onFixCustomer ?? (id) async => fixedCustomers.add(id),
            onFixBusiness: onFixBusiness ?? () async => fixedBusiness++,
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
    await _settle(tester);
  }

  testWidgets('every customer is ticked; the one filled action says how many '
      'and how much', (tester) async {
    await pump(tester);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.text('Ben Birk'), findsOneWidget);
    expect(find.text('Issue 2 invoices · €165.50'), findsOneWidget);
    expect(find.textContaining('2 OF 2 SELECTED'), findsOneWidget);
    expect(
      find.textContaining('can no longer be edited'),
      findsOneWidget,
      reason: 'the rule is said before issuing',
    );
    await tester.tap(_key('invoice-month-select-ben'));
    await _settle(tester);
    expect(find.text('Issue 1 invoice · €120.00'), findsOneWidget);
    expect(find.textContaining('1 OF 2 SELECTED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the All row ticks and unticks every free customer', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_key('invoice-month-all'));
    await _settle(tester);
    expect(find.textContaining('0 OF 2 SELECTED'), findsOneWidget);
    await tester.tap(_key('invoice-month-all'));
    await _settle(tester);
    expect(find.textContaining('2 OF 2 SELECTED'), findsOneWidget);
  });

  testWidgets('issuing ends on a result page that claims no e-mail', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(find.text('2 invoices issued'), findsOneWidget);
    expect(find.text('Issued'), findsNWidgets(2));
    expect(
      find.text('Each customer sees it in their account now.'),
      findsOneWidget,
    );
    expect(find.textContaining('e-mail'), findsNothing);
    expect(find.textContaining('sent'), findsNothing);
    expect(repo.invoices, hasLength(2));
    expect(_key('invoice-month-retry'), findsNothing);
  });

  group('a customer with a gap', () {
    testWidgets('is unticked, named "Needs a fix", cannot be ticked or '
        'issued, and is counted', (tester) async {
      repo.missing['ben'] = ['buyer_address'];
      await pump(tester);
      expect(_key('invoice-month-status-ben'), findsOneWidget);
      expect(find.textContaining('Needs a fix'), findsWidgets);
      expect(find.text('1 needs a fix'), findsOneWidget);
      expect(find.text('Issue 1 invoice · €120.00'), findsOneWidget);
      await tester.tap(_key('invoice-month-select-ben'));
      await _settle(tester);
      expect(
        find.text('Issue 1 invoice · €120.00'),
        findsOneWidget,
        reason: 'a row that needs a fix cannot be ticked',
      );
      await tester.tap(_key('invoice-month-issue'));
      await _settle(tester);
      expect(repo.invoices, hasLength(1), reason: 'only Anna was issued');
    });

    testWidgets('Fix opens the place, and on return the row is free again', (
      tester,
    ) async {
      repo.missing['ben'] = ['buyer_address'];
      await pump(tester);
      expect(_key('invoice-month-fix-ben'), findsOneWidget);
      // The details are completed while the person is away.
      repo.missing.clear();
      await tester.tap(_key('invoice-month-fix-ben'));
      await _settle(tester);
      expect(fixedCustomers, ['ben']);
      expect(_key('invoice-month-fix-ben'), findsNothing);
      expect(find.text('Issue 2 invoices · €165.50'), findsOneWidget);
      expect(find.text('1 needs a fix'), findsNothing);
    });
  });

  testWidgets('a gap of the business is said once, with one Fix, and the bar '
      'waits', (tester) async {
    repo.missing['anna'] = ['seller_address'];
    repo.missing['ben'] = ['seller_address'];
    await pump(tester);
    expect(_key('invoice-month-business-notice'), findsOneWidget);
    expect(_key('invoice-month-business-fix'), findsOneWidget);
    expect(_key('invoice-month-fix-anna'), findsNothing);
    expect(_key('invoice-month-fix-ben'), findsNothing);
    final bar = tester.widget<FilledButton>(find.descendant(of: _key('invoice-month-issue'), matching: find.byType(FilledButton)));
    expect(bar.onPressed, isNull, reason: 'nothing can be issued yet');
    repo.missing.clear();
    await tester.tap(_key('invoice-month-business-fix'));
    await _settle(tester);
    expect(fixedBusiness, 1);
    expect(_key('invoice-month-business-notice'), findsNothing);
    final again = tester.widget<FilledButton>(find.descendant(of: _key('invoice-month-issue'), matching: find.byType(FilledButton)));
    expect(again.onPressed, isNotNull);
  });

  testWidgets('a readiness read that fails leaves the row free; the server '
      'decides at issue time', (tester) async {
    repo
      ..failing.add('ben')
      ..missing['anna'] = ['buyer_address'];
    await pump(tester);
    expect(
      _key('invoice-month-status-anna'),
      findsOneWidget,
      reason: 'the read of the other row did mark it',
    );
    expect(_key('invoice-month-status-ben'), findsNothing);
    expect(find.text('Issue 1 invoice · €45.50'), findsOneWidget);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(
      repo.invoices,
      hasLength(1),
      reason: 'Ben: his failed read blocked nothing',
    );
  });

  testWidgets('a customer the server refused is listed in words, the result '
      'is partial, and the retry is for those only', (tester) async {
    // Anna is invoiced for October already: the server refuses her alone.
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: '2026-10',
    );
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(find.text('1 of 2 invoices issued'), findsOneWidget);
    expect(find.text('Not done'), findsOneWidget);
    expect(find.text('Anna Alder'), findsOneWidget);
    expect(find.text('Ben Birk'), findsOneWidget);
    expect(
      find.text('The server did not issue it.'),
      findsNothing,
      reason: 'never that sentence',
    );
    expect(find.text('What was not done stays in To do.'), findsOneWidget);
    expect(_key('invoice-month-retry'), findsOneWidget);
    expect(find.text('Retry for these'), findsOneWidget);
    expect(
      find.text('The customer sees it in their account now.'),
      findsOneWidget,
      reason: 'one invoice, one customer',
    );
    expect(repo.invoices, hasLength(2), reason: 'only Ben was added');
  });

  testWidgets('a customer the administrator unticked is never ticked again by '
      'a read that arrives late', (tester) async {
    repo.held['ben'] = Completer<void>();
    await pump(tester);
    await tester.tap(_key('invoice-month-select-ben'));
    await _settle(tester);
    expect(find.text('Issue 1 invoice · €120.00'), findsOneWidget);
    repo.held['ben']!.complete();
    await _settle(tester);
    expect(
      find.text('Issue 1 invoice · €120.00'),
      findsOneWidget,
      reason: 'the read said "free"; the untick stands',
    );
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(repo.invoices, hasLength(1), reason: 'Anna only');
  });

  testWidgets('a business Fix reads everyone again and undoes no untick', (
    tester,
  ) async {
    repo.missing['anna'] = ['seller_address'];
    repo.missing['ben'] = ['seller_address'];
    await pump(tester);
    await tester.tap(_key('invoice-month-select-ben'));
    await _settle(tester);
    // The business details are completed while the person is away.
    repo.missing.clear();
    await tester.tap(_key('invoice-month-business-fix'));
    await _settle(tester);
    expect(find.text('Issue 1 invoice · €120.00'), findsOneWidget);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(repo.invoices, hasLength(1), reason: 'Ben stayed unticked');
  });

  testWidgets('leaving while issuing is held, and the run goes on if the page '
      'is gone', (tester) async {
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await tester.pump();
    // The page goes away mid-run.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(repo.invoices, hasLength(2), reason: 'the run finished by itself');
  });

  testWidgets('a request a validator declined is said as the issue form says '
      'it and is not retried', (tester) async {
    // A receipt of a declined request: its look returns the declined outcome.
    const report = MonthIssueReport({
      'anna': InvoiceIssueRefused(
        InvoiceIssueAttempt(
          workspaceId: 'ws-1',
          memberId: 'anna',
          period: '2026-10',
        ),
        InvoiceIssueDeclined('evt-1'),
      ),
    });
    expect(report.declined, ['anna']);
    expect(report.refused, isEmpty);
    expect(report.notDone, ['anna']);
    await pumpApp(
      tester,
      MonthResultView(
        report: report,
        entries: _entries,
        currency: 'EUR',
        busy: false,
        onRetry: () {},
        onFixCustomer: (_) async {},
        onFixBusiness: () async {},
      ),
      size: const Size(390, 844),
      overrides: standardTestOverrides(money: repo),
    );
    await _settle(tester);
    expect(
      find.text(
        'The validation was declined or expired. No invoice was issued.',
      ),
      findsOneWidget,
      reason: 'one wording for every surface that issues',
    );
    expect(find.text('Could not be issued. Try again.'), findsNothing);
    expect(_key('invoice-month-retry'), findsNothing);
  });

  testWidgets('nothing issued is the failure tone: "No invoice issued"', (
    tester,
  ) async {
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: '2026-10',
    );
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'ben',
      period: '2026-10',
    );
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    expect(find.text('No invoice issued'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(_key('invoice-month-retry'), findsOneWidget);
  });

  for (final (width, scale) in [(320.0, 1.3), (390.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('review and result keep the rules at $width px, ×$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      repo.missing['ben'] = ['buyer_address'];
      await pump(tester, size: Size(width, 3000));
      expect(guardProblems(tester, width: width), isEmpty);
      await tester.tap(_key('invoice-month-issue'));
      await _settle(tester);
      expect(guardProblems(tester, width: width), isEmpty);
      semantics.dispose();
    });
  }

  // The pictures a pull request attaches (SHEET=1), at a phone's own height.
  testWidgets('sheet: review with a row that needs a fix, and the results', (
    tester,
  ) async {
    await loadSheetFonts();
    repo.missing['ben'] = ['buyer_address'];
    await pump(tester);
    await writeSheet(tester, sheet: 'invoice-month', name: 'review-fix');
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    await writeSheet(tester, sheet: 'invoice-month', name: 'result');
  });

  testWidgets('sheet: a partial result', (tester) async {
    await loadSheetFonts();
    await repo.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'anna',
      period: '2026-10',
    );
    await pump(tester);
    await tester.tap(_key('invoice-month-issue'));
    await _settle(tester);
    await writeSheet(tester, sheet: 'invoice-month', name: 'result-partial');
  });

  testWidgets('sheet: a business gap', (tester) async {
    await loadSheetFonts();
    repo.missing['anna'] = ['seller_address'];
    repo.missing['ben'] = ['seller_address'];
    await pump(tester);
    await writeSheet(tester, sheet: 'invoice-month', name: 'review-business');
  });
}
