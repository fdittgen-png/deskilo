// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A scheduled expense names who it pays: the creation form offers the
// workspace's ACTIVE suppliers, the schedule keeps the one picked, an
// archived supplier is no longer offered, and the schedule that already
// names it still reads its name. Without the suppliers flag, or without a
// supplier to offer, the form asks nothing.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/application/schedule_expense.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

const _acme = Supplier(id: 'sup-acme', number: '1', name: 'ACME Sarl');
const _old = Supplier(
  id: 'sup-old',
  number: '2',
  name: 'Old Lessor',
  status: SupplierStatus.archived,
);

Future<void> _pump(
  WidgetTester tester, {
  required FakeMoneyRepository money,
  required FakeSupplierRepository suppliers,
  bool suppliersOn = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final ws = workspace.workspaces.first;
  workspace.workspaces[0] = ws.copyWith(
    featureFlags: {
      ...ws.featureFlags,
      'financeFaces': false,
      'services': true,
      'supplyExpenses': suppliersOn,
    },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money, workspace: workspace),
        supplierRepositoryProvider.overrideWithValue(suppliers),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('My finances'));
  await tester.pumpAndSettle();
}

Future<void> _openNewSchedule(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('scheduled-expenses-button')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('scheduled-expenses-button')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('schedule-new')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('schedule-new')));
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('schedule-title')), 'Rent');
  await tester.enterText(find.byKey(const ValueKey('schedule-amount')), '800');
  await tester.ensureVisible(find.byKey(const ValueKey('schedule-submit')));
  await tester.tap(find.byKey(const ValueKey('schedule-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a new scheduled expense picks an active supplier; once archived it '
    'is no longer offered and the schedule still reads its name',
    (tester) async {
      final money = FakeMoneyRepository();
      final suppliers = FakeSupplierRepository()
        ..suppliers.addAll([_acme, _old]);
      await _pump(tester, money: money, suppliers: suppliers);
      await _openNewSchedule(tester);

      final picker = find.byKey(const ValueKey('schedule-supplier'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      // The archived supplier is not offered.
      expect(find.text('2 · Old Lessor'), findsNothing);
      await tester.tap(find.text('1 · ACME Sarl').last);
      await tester.pumpAndSettle();
      await _fillAndSubmit(tester);

      final id = money.expenseSchedules.single.id;
      expect(money.expenseScheduleSuppliers, {id: 'sup-acme'});
      expect(money.expenseSchedules.single.supplierId, 'sup-acme');
      // The list names who the schedule pays.
      expect(find.textContaining('ACME Sarl'), findsOneWidget);

      // Archiving hides it from the picker; the schedule keeps reading it.
      await suppliers.setStatus('sup-acme', SupplierStatus.archived);
      // The success snackbar would sit over the list's buttons.
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .clearSnackBars();
      Navigator.of(tester.element(find.byKey(const ValueKey('schedule-new'))))
          .pop();
      await tester.pumpAndSettle();
      await _openNewSchedule(tester);
      expect(
        find.byKey(const ValueKey('schedule-supplier')),
        findsNothing,
        reason: 'no active supplier left to offer',
      );
      Navigator.of(tester.element(find.byKey(const ValueKey('schedule-title'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('schedule-$id')), findsOneWidget);
      expect(find.textContaining('ACME Sarl'), findsOneWidget);
    },
  );

  testWidgets('no supplier picked: the schedule names none', (tester) async {
    final money = FakeMoneyRepository();
    final suppliers = FakeSupplierRepository()..suppliers.add(_acme);
    await _pump(tester, money: money, suppliers: suppliers);
    await _openNewSchedule(tester);
    expect(find.byKey(const ValueKey('schedule-supplier')), findsOneWidget);
    await _fillAndSubmit(tester);
    expect(money.expenseSchedules, hasLength(1));
    expect(money.expenseScheduleSuppliers, isEmpty);
  });

  testWidgets('with the suppliers switched off the form asks nothing', (
    tester,
  ) async {
    final money = FakeMoneyRepository();
    final suppliers = FakeSupplierRepository()..suppliers.add(_acme);
    await _pump(tester, money: money, suppliers: suppliers, suppliersOn: false);
    await _openNewSchedule(tester);
    expect(find.byKey(const ValueKey('schedule-supplier')), findsNothing);
  });

  test('the command names the supplier only after the schedule exists, and '
      'a refused schedule names none', () async {
    final money = FakeMoneyRepository();
    final command = ExpenseSchedules(money);
    expect(
      await command.schedule(
        workspaceId: 'ws-1',
        title: '',
        amountCents: 100,
        startsOn: DateTime.utc(2026, 11),
        unit: ScheduleUnit.month,
        details: const ScheduleDetails(supplierId: 'sup-acme'),
      ),
      isFalse,
    );
    expect(money.expenseScheduleSuppliers, isEmpty);
    expect(
      await command.schedule(
        workspaceId: 'ws-1',
        title: 'Rent',
        amountCents: 80000,
        startsOn: DateTime.utc(2026, 11),
        unit: ScheduleUnit.month,
        details: const ScheduleDetails(supplierId: 'sup-acme'),
      ),
      isTrue,
    );
    expect(money.expenseScheduleSuppliers.values.single, 'sup-acme');
  });

  test('a schedule row decodes the supplier it pays', () {
    final s = ExpenseSchedule.fromDb({
      'id': 's1',
      'workspace_id': 'w',
      'member_id': 'm',
      'title': 'Rent',
      'amount_cents': 80000,
      'starts_on': '2026-11-01',
      'unit': 'month',
      'supplier_id': 'sup-acme',
    });
    expect(s.supplierId, 'sup-acme');
  });
}
