// SPDX-License-Identifier: 0BSD
//
// #767 — scheduled (recurring) expenses. The schedule is created from
// the Payments face and goes to the validators; a presented occurrence
// confirmed at the validated amount lands settled at once; a different
// amount demands an explanation and goes through validation; a rejected
// one is resent from the same card.
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'money_screen_test.dart' show pumpMoney;

ExpenseOccurrence occurrence({
  String id = 'occ-1',
  OccurrenceStatus status = OccurrenceStatus.awaitingMember,
}) =>
    ExpenseOccurrence(
      id: id,
      scheduleId: 'schedule-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      dueOn: DateTime.utc(2026, 8, 1),
      amountCents: 3999,
      status: status,
      scheduleTitle: 'Internet',
      scheduledAmountCents: 3999,
    );

void main() {
  testWidgets('scheduling a recurring expense sends rule, bounds and amount',
      (tester) async {
    final money = await pumpMoney(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('scheduled-expenses-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('scheduled-expenses-button')));
    await tester.pumpAndSettle();
    expect(find.text('No scheduled expense yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('schedule-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('schedule-title')), 'Internet');
    await tester.enterText(
        find.byKey(const ValueKey('schedule-amount')), '39.99');
    await tester.enterText(find.byKey(const ValueKey('schedule-every')), '2');
    await tester.enterText(find.byKey(const ValueKey('schedule-times')), '12');
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-submit')));
    await tester.tap(find.byKey(const ValueKey('schedule-submit')));
    await tester.pumpAndSettle();

    final created = money.createdSchedules.single;
    expect(created.title, 'Internet');
    expect(created.amountCents, 3999);
    expect(created.unit, ScheduleUnit.month);
    expect(created.every, 2);
    expect(created.repeatCount, 12);
    expect(
      find.text('Scheduled — waiting for the validators to confirm it.'),
      findsOneWidget,
    );
  });

  testWidgets('an occurrence confirmed at the validated amount lands settled',
      (tester) async {
    final money = await pumpMoney(
      tester,
      money: FakeMoneyRepository()..expenseOccurrences.add(occurrence()),
    );
    expect(find.byKey(const ValueKey('occurrence-occ-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('occurrence-confirm-occ-1')));
    await tester.pumpAndSettle();
    expect(money.confirmedOccurrences.single.amountCents, 3999);
    expect(money.expenseOccurrences.single.status, OccurrenceStatus.added);
  });

  testWidgets('a different amount demands the explanation, then goes to '
      'validation', (tester) async {
    final money = await pumpMoney(
      tester,
      money: FakeMoneyRepository()..expenseOccurrences.add(occurrence()),
    );
    await tester.enterText(
        find.byKey(const ValueKey('occurrence-amount-occ-1')), '45.99');
    await tester.pump();
    // The reason field appears; confirming without it is refused.
    expect(
        find.byKey(const ValueKey('occurrence-reason-occ-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('occurrence-confirm-occ-1')));
    await tester.pumpAndSettle();
    expect(find.text('A different amount needs an explanation.'),
        findsOneWidget);
    expect(money.confirmedOccurrences, isEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('occurrence-reason-occ-1')), 'price rise');
    await tester.tap(find.byKey(const ValueKey('occurrence-confirm-occ-1')));
    await tester.pumpAndSettle();
    final sent = money.confirmedOccurrences.single;
    expect(sent.amountCents, 4599);
    expect(sent.reason, 'price rise');
    expect(money.expenseOccurrences.single.status,
        OccurrenceStatus.pendingValidation);
  });

  testWidgets('a rejected occurrence explains itself and resends',
      (tester) async {
    final money = await pumpMoney(
      tester,
      money: FakeMoneyRepository()
        ..expenseOccurrences.add(occurrence(status: OccurrenceStatus.rejected)),
    );
    expect(
      find.textContaining('The validators rejected it'),
      findsOneWidget,
    );
    await tester.enterText(
        find.byKey(const ValueKey('occurrence-reason-occ-1')), 'as billed');
    await tester.tap(find.byKey(const ValueKey('occurrence-confirm-occ-1')));
    await tester.pumpAndSettle();
    expect(money.confirmedOccurrences.single.reason, 'as billed');
  });

  testWidgets('the create sheet scrolls its tail above a keyboard (#769)',
      (tester) async {
    await pumpMoney(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('scheduled-expenses-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('scheduled-expenses-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('schedule-new')));
    await tester.pumpAndSettle();
    // A software keyboard eats most of the height; before SheetShell
    // scrolled, the tail of the form (the submit button) was cut off.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-submit')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('schedule-submit')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('with the feature off there is no button and no card',
      (tester) async {
    await pumpMoney(
      tester,
      money: FakeMoneyRepository()..expenseOccurrences.add(occurrence()),
      workspace: FakeWorkspaceRepository.withWorkspace(
        featureFlags: {'scheduledExpenses': false},
      ),
    );
    expect(find.byKey(const ValueKey('scheduled-expenses-button')),
        findsNothing);
    expect(find.byKey(const ValueKey('occurrence-occ-1')), findsNothing);
    expect(WorkspaceFeature.scheduledExpenses.dbKey, 'scheduledExpenses');
  });
}
