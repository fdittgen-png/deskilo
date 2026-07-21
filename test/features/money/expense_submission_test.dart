// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import 'money_screen_test.dart' show pumpMoney;

void main() {
  testWidgets('submitting an expense captures amount, category, description',
      (tester) async {
    final money = await pumpMoney(tester);

    // The prominent entitlement card (0041) pushes the action buttons down
    // the lazily-built bill list — scroll the expense action into view.
    await tester.scrollUntilVisible(
      find.text('Submit an expense'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Submit an expense'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '42.90',
    );
    await tester.tap(find.text('Coffee & kitchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supplies').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Description'),
      'Printer paper',
    );
    await tester.tap(find.text('Submit for confirmation'));
    await tester.pumpAndSettle();

    final expense = money.submittedExpenses.single;
    expect(expense.amountCents, 4290);
    expect(expense.category, 'supplies');
    expect(expense.description, 'Printer paper');
    expect(
      find.text('Expense submitted — waiting for approval.'),
      findsOneWidget,
    );
  });

  testWidgets('the events feed narrates payments and expenses with amounts',
      (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([
        WorkspaceEvent(
          id: 'evt-pay',
          workspaceId: 'ws-1',
          type: EventType.payment,
          action: EventAction.submitted,
          actorMemberId: 'member-1',
          subjectMemberId: 'member-1',
          payload: const {'amount_cents': 15000},
          status: EventStatus.confirmed,
          createdAt: DateTime.now(),
        ),
        WorkspaceEvent(
          id: 'evt-exp',
          workspaceId: 'ws-1',
          type: EventType.expense,
          action: EventAction.submitted,
          actorMemberId: 'member-1',
          subjectMemberId: 'member-1',
          payload: const {'amount_cents': 4290, 'category': 'supplies'},
          status: EventStatus.confirmed,
          createdAt: DateTime.now(),
        ),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(events: events),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    // #230: the events feed is behind the app-bar bell, no longer a tab.
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Flo recorded a payment of'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Flo submitted an expense of'),
      findsOneWidget,
    );
  });
}
