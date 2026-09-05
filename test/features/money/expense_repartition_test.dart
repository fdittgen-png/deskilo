// SPDX-License-Identifier: 0BSD
//
// #828 — the distribution sheet: the shares previewed to the cent for
// every key, a reversal as credits, the booking landing as adjustment
// lines on the period's usage invoice, the pending path when a rule
// exists, the history, and the migration's contract.
import 'dart:io';

import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/presentation/widgets/expense_repartition_sheet.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

Future<FakeMoneyRepository> _pumpSheet(
  WidgetTester tester, {
  FakeMoneyRepository? money,
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final m = money ?? FakeMoneyRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana', 'member-3': 'Ben'}
    ..otherMembers.addAll([
      const Member(
        id: 'member-2',
        workspaceId: 'ws-1',
        userId: 'user-2',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        subscriptionPct: 50,
      ),
      const Member(
        id: 'member-3',
        workspaceId: 'ws-1',
        userId: 'user-3',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        subscriptionPct: 50,
      ),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, money: m),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            // Under the app, so the sheet finds its localizations.
            child: Consumer(
              builder: (context, ref, _) => FilledButton(
                key: const ValueKey('open'),
                onPressed: () => showExpenseRepartitionSheet(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return m;
}

/// Types into a field the way a person does: scroll to it, tap, type.
Future<void> _type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
  await tester.enterText(f, text);
  await tester.pump();
}

String _share(WidgetTester tester, String memberId) => tester
    .widget<Text>(find.byKey(ValueKey('repartition-share-$memberId')))
    .data!;

void main() {
  testWidgets('equal shares preview to the cent; the subscription key '
      'weighs by percentage; booking lands adjustment charges on the '
      'period that the usage invoice picks up', (tester) async {
    final money = await _pumpSheet(tester);
    await tester.enterText(
        find.byKey(const ValueKey('repartition-title')), 'Cleaning');
    await tester.enterText(
        find.byKey(const ValueKey('repartition-amount')), '100');
    await tester.pumpAndSettle();
    // #872 — the shares are the assistant's second step.
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    expect(_share(tester, 'member-1'), contains('33.34'));
    expect(_share(tester, 'member-2'), contains('33.33'));
    expect(find.byKey(const ValueKey('repartition-sum')), findsOneWidget);

    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();
    // 100 / 50 / 50 → 50 % / 25 % / 25 %.
    expect(_share(tester, 'member-1'), contains('50.00'));
    expect(_share(tester, 'member-2'), contains('25.00'));

    await tester.ensureVisible(find.byKey(const ValueKey('repartition-submit')));
    await tester.tap(find.byKey(const ValueKey('repartition-submit')));
    await tester.pumpAndSettle();
    expect(money.repartitions.single.title, 'Cleaning');
    expect(money.repartitions.single.method, RepartitionMethod.subscription);
    expect(money.repartitions.single.status, 'confirmed');
    final rows = money.ledger
        .where((e) => e.category == LedgerCategory.adjustment)
        .toList();
    expect(rows.length, 3);
    expect(rows.every((e) => e.kind == LedgerKind.charge), isTrue);
    expect(rows.firstWhere((e) => e.memberId == 'member-1').amountCents, 5000);

    // The period's USAGE invoice carries the share as a line.
    final period = money.repartitions.single.period;
    final id = await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-2',
      period: period,
      kind: InvoiceKind.usage,
    );
    final invoice = money.invoices.firstWhere((i) => i.id == id);
    expect(
        invoice.lines.any(
            (l) => l.kind == 'adjustment' && l.amountCents == 2500 && l.label == 'Cleaning'),
        isTrue);
  });

  testWidgets('a reversal books credits, a custom key weighs by what was '
      'typed, and a key that leaves everyone out says so', (tester) async {
    final money = await _pumpSheet(tester);
    await tester.enterText(
        find.byKey(const ValueKey('repartition-title')), 'Refund heating');
    await tester.enterText(
        find.byKey(const ValueKey('repartition-amount')), '30');
    await tester.tap(find.byKey(const ValueKey('repartition-reverse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    expect(_share(tester, 'member-1'), contains('-'));

    await tester.tap(find.text('Custom key'));
    await tester.pumpAndSettle();
    for (final m in ['member-1', 'member-2', 'member-3']) {
      await _type(tester, 'repartition-weight-$m', '0');
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('repartition-no-shares')), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('repartition-submit')))
            .onPressed,
        isNull);

    await _type(tester, 'repartition-weight-member-1', '2');
    await _type(tester, 'repartition-weight-member-2', '1');
    await tester.pumpAndSettle();
    // The sign leads the currency symbol: '-€20.00'.
    expect(_share(tester, 'member-1'), allOf(startsWith('-'), contains('20.00')));
    expect(_share(tester, 'member-2'), allOf(startsWith('-'), contains('10.00')));
    expect(_share(tester, 'member-3'), contains('0.00'));

    await tester.ensureVisible(find.byKey(const ValueKey('repartition-submit')));
    await tester.tap(find.byKey(const ValueKey('repartition-submit')));
    await tester.pumpAndSettle();
    final rows = money.ledger
        .where((e) => e.category == LedgerCategory.adjustment)
        .toList();
    expect(rows.map((e) => e.memberId), ['member-1', 'member-2']);
    expect(rows.every((e) => e.kind == LedgerKind.credit), isTrue);
    expect(money.repartitions.single.isReversal, isTrue);
  });

  testWidgets('with a validation rule the distribution waits: nothing is '
      'booked, the history shows it pending', (tester) async {
    final money = FakeMoneyRepository()..repartitionPolicyConfigured = true;
    await _pumpSheet(tester, money: money);
    await tester.enterText(
        find.byKey(const ValueKey('repartition-title')), 'Chair');
    await tester.enterText(
        find.byKey(const ValueKey('repartition-amount')), '90');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('repartition-submit')));
    await tester.tap(find.byKey(const ValueKey('repartition-submit')));
    await tester.pumpAndSettle();
    expect(money.ledger, isEmpty);
    expect(money.repartitions.single.isPending, isTrue);
    expect(find.textContaining('once validated'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('repartition-history-rep-1')),
        findsOneWidget);
    expect(find.textContaining('Awaiting validation'), findsOneWidget);
  });

  testWidgets('the Invoices header offers the distribution behind its flag',
      (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    expect(find.byKey(const ValueKey('invoice-distribute-button')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-distribute-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('repartition-title')), findsOneWidget);
  });

  testWidgets('flag off: no distribution button', (tester) async {
    await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'expenseRepartition': false}),
    );
    expect(find.byKey(const ValueKey('invoice-distribute-button')),
        findsNothing);
  });

  test('migration 0147 carries the table, the RPC, the event type and the '
      'trigger', () {
    final sql = File('supabase/migrations/0147_expense_repartition.sql')
        .readAsStringSync();
    for (final what in [
      'create table if not exists public.expense_repartitions',
      "check (method in ('equal','subscription','usage','custom'))",
      'create or replace function public.distribute_expense(',
      "'expense_repartition'));",
      'create or replace function public.apply_expense_repartition(uuid)'
          .replaceAll('(uuid)', '(p_id uuid)'),
      "'adjustment'",
      'create trigger events_apply_expense_repartition',
      "if v_sum <> p_amount_cents then",
    ]) {
      expect(sql, contains(what), reason: what);
    }
  });
}
