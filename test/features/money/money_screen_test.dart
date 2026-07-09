// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpMoney(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeEventRepository? events,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, events: events),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

/// The period before 'yyyy-MM'.
String previousPeriod(String period) {
  final year = int.parse(period.substring(0, 4));
  final month = int.parse(period.substring(5));
  return DateFormat('yyyy-MM').format(DateTime(year, month - 1));
}

void main() {
  testWidgets(
      'the bill shows the localized month, subscription, entitlement, '
      'overage and the outstanding balance state', (tester) async {
    await pumpMoney(tester);

    expect(
      find.text(DateFormat.yMMMM('en').format(DateTime.now())),
      findsOneWidget,
    );
    expect(find.text('Subscription 50%'), findsOneWidget);
    expect(
      find.text('24 of 22 half-days used (22 open days)'),
      findsOneWidget,
    );
    expect(find.text('2 extra half-days'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);
  });

  testWidgets('a settled statement shows the settled state', (tester) async {
    final money = FakeMoneyRepository();
    money.statement = money.statement.copyWith(
      creditsCents: 20000,
      balanceCents: 3400,
    );
    await pumpMoney(tester, money: money);

    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Outstanding'), findsNothing);
  });

  testWidgets(
      'all bill sections render: services with total, pending open '
      'positions with badge, payments & credits', (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final period = currentPeriod();
    final money = FakeMoneyRepository();
    money.ledger.addAll([
      LedgerEntry(
        id: 'l-coffee',
        memberId: 'member-1',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 300,
        description: 'Coffee x2',
        period: period,
        createdAt: DateTime.now(),
      ),
      LedgerEntry(
        id: 'l-payment',
        memberId: 'member-1',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 15000,
        description: 'Bank transfer',
        period: period,
        createdAt: DateTime.now(),
      ),
    ]);
    final events = FakeEventRepository();
    events.events.add(
      WorkspaceEvent(
        id: 'evt-pending',
        workspaceId: 'ws-1',
        type: EventType.serviceCharge,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: {
          'name': 'Printing',
          'quantity': 4,
          'amount_cents': 80,
          'period': period,
        },
        status: EventStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    await pumpMoney(tester, money: money, events: events);

    expect(find.text('Consumed services'), findsOneWidget);
    expect(find.text('Coffee x2'), findsOneWidget);
    expect(find.text('Services total'), findsOneWidget);
    expect(find.text('−€3.00'), findsNWidgets(2)); // row + section total

    expect(find.text('Open positions'), findsOneWidget);
    expect(find.text('pending validation'), findsOneWidget);
    expect(find.text('Printing ×4'), findsOneWidget);
    expect(find.text('−€0.80'), findsOneWidget);

    expect(find.text('Payments & credits'), findsOneWidget);
    expect(find.text('Bank transfer'), findsOneWidget);
    expect(find.text('+€150.00'), findsOneWidget);

    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets('empty sections are hidden entirely', (tester) async {
    await pumpMoney(tester);

    expect(find.text('Consumed services'), findsNothing);
    expect(find.text('Open positions'), findsNothing);
    expect(find.text('Payments & credits'), findsNothing);
    // The subscription block and balance footer always render.
    expect(find.text('Subscription 50%'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
  });

  testWidgets(
      'the period chevrons query the neighbouring month and the forward '
      'chevron stops at the current period', (tester) async {
    final previous = previousPeriod(currentPeriod());
    final money = FakeMoneyRepository();
    money.statements[previous] = money.statement.copyWith(
      period: previous,
      subscriptionPct: 25,
      feeCents: 0,
    );
    await pumpMoney(tester, money: money);

    // At the current period the forward chevron is disabled.
    final forward = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(forward.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(money.fetchedPeriods, contains(previous));
    expect(find.text('Subscription 25%'), findsOneWidget);
    final year = int.parse(previous.substring(0, 4));
    final month = int.parse(previous.substring(5));
    expect(
      find.text(DateFormat.yMMMM('en').format(DateTime(year, month))),
      findsOneWidget,
    );

    // Going forward again returns to the current period.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Subscription 50%'), findsOneWidget);
  });

  testWidgets(
      'pending payments and expenses appear as open positions only on the '
      'current period', (tester) async {
    final events = FakeEventRepository();
    events.events.add(
      WorkspaceEvent(
        id: 'evt-payment',
        workspaceId: 'ws-1',
        type: EventType.payment,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: const {'amount_cents': 5000, 'note': 'transfer'},
        status: EventStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    await pumpMoney(tester, events: events);

    expect(find.text('Open positions'), findsOneWidget);
    expect(find.text('+€50.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('Open positions'), findsNothing);
  });

  testWidgets('recording a payment submits cents for confirmation',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Record a payment'), 100);
    await tester.tap(find.text('Record a payment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '150,50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Note (optional)'),
      'July rent',
    );
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(money.recordedPayments.single.amountCents, 15050);
    expect(money.recordedPayments.single.note, 'July rent');
    expect(
      find.text('Payment submitted — waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'adding consumption records service, quantity and period (#129)',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Add consumption'), 100);
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();

    // Coffee is the first active service (name-ordered); bump quantity.
    expect(find.text('Coffee — €1.50'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final recorded = money.recordedServiceCharges.single;
    expect(recorded.workspaceId, 'ws-1');
    expect(recorded.subjectMemberId, 'member-1');
    expect(recorded.serviceId, 'service-coffee');
    expect(recorded.quantity, 2);
    expect(recorded.period, currentPeriod());
    expect(
      find.text('Consumption recorded — waiting for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('the consumption sheet offers only active services',
      (tester) async {
    final money = await pumpMoney(tester);

    await tester.scrollUntilVisible(find.text('Add consumption'), 100);
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee — €1.50'));
    await tester.pumpAndSettle();
    // Locker is inactive and must not be offered.
    expect(find.textContaining('Locker'), findsNothing);
    await tester.tap(find.text('Printing — €0.20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    expect(
      money.recordedServiceCharges.single.serviceId,
      'service-printing',
    );
    expect(money.recordedServiceCharges.single.quantity, 1);
  });
}
