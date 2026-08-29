// SPDX-License-Identifier: 0BSD
//
// THE CALENDAR HUB (#718): the calendar is a selector; what it selects
// is one feed of every dated fact the member may see, each row leading
// to its source. And the ACCESS rules (#719): a kind the server declines
// is shown as locked, never as an empty day.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/domain/calendar_repository.dart';
import 'package:deskilo/features/money/providers/money_focus_controller.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_calendar_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

CalendarItem _item(CalendarKind kind, String id, DateTime at,
        {String member = 'member-1', CalendarLink? link, int? cents}) =>
    CalendarItem(
      kind: kind,
      id: id,
      at: at,
      memberId: member,
      title: 'Desk A1',
      link: link,
      amountCents: cents,
      currency: 'EUR',
    );

Future<({FakeCalendarRepository calendar, FakeWorkspaceRepository workspace})>
    pumpHub(
  WidgetTester tester, {
  bool admin = true,
  Map<String, dynamic> flags = const {},
}) async {
  final today = kTestNow;
  final calendar = FakeCalendarRepository()
    ..items.addAll([
      _item(CalendarKind.reservation, 'r1',
          DateTime.utc(today.year, today.month, today.day, 9),
          link: const ReservationLink('res-1')),
      _item(CalendarKind.message, 'm1',
          DateTime.utc(today.year, today.month, today.day, 10),
          link: const ConversationLink('conv-ana')),
      _item(CalendarKind.payment, 'p1',
          DateTime.utc(today.year, today.month, today.day, 11),
          link: const LedgerLink('2026-08'), cents: 4000),
      // Yesterday: must NOT show on a single-day selection.
      _item(CalendarKind.invoice, 'i-old',
          DateTime.utc(today.year, today.month, today.day - 1, 12)),
    ]);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(Conversation(
      id: 'conv-ana',
      kind: ConversationKind.direct,
      otherMemberId: 'member-2',
      lastAt: DateTime.utc(2026, 8, 27),
    ));
  if (!admin) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  // A phone-sized viewport: the filter row scrolls horizontally and the
  // feed vertically, and taps must land on what is on screen.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(
      calendar: calendar,
      workspace: workspace,
      floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
    ),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  await tapNavIcon(tester, Icons.calendar_month_outlined);
  return (calendar: calendar, workspace: workspace);
}

void main() {
  testWidgets('today is selected and the feed shows every kind of the day',
      (tester) async {
    final r = await pumpHub(tester);

    expect(find.byKey(const ValueKey('calendar-feed')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-m1')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-p1')), findsOneWidget);
    // Yesterday's invoice is outside a one-day selection.
    expect(find.byKey(const ValueKey('calendar-item-i-old')), findsNothing);
    // The query the server got was a half-open day, for ME, all kinds.
    final q = r.calendar.queries.last;
    expect(q.to.difference(q.from), const Duration(days: 1));
    expect(q.kinds, isNull);
    expect(q.memberId, isNull);
  });

  testWidgets('a kind filter narrows the QUERY, not just the list',
      (tester) async {
    final r = await pumpHub(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-kind-payment')));
    await tester.tap(find.byKey(const ValueKey('calendar-kind-payment')));
    await tester.pumpAndSettle();

    expect(r.calendar.queries.last.kinds, {CalendarKind.payment});
    expect(find.byKey(const ValueKey('calendar-item-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-r1')), findsNothing);
  });

  testWidgets('a locked kind says so instead of showing an empty day',
      (tester) async {
    final r = await pumpHub(tester);
    r.calendar.locked = {CalendarKind.message};
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-kind-message')));
    await tester.tap(find.byKey(const ValueKey('calendar-kind-message')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-m1')), findsNothing);
  });

  testWidgets('rows lead somewhere: a payment opens the Money month',
      (tester) async {
    await pumpHub(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-item-p1')));
    await tester.tap(find.byKey(const ValueKey('calendar-item-p1')));
    await tester.pumpAndSettle();

    // Landed on the Money tab, on the requested month (the focus
    // request was consumed and cleared by the screen).
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Money')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
        tester.element(find.byType(AppBar).first));
    expect(container.read(moneyFocusControllerProvider), isNull);
  });

  testWidgets('a message row opens the conversation thread', (tester) async {
    await pumpHub(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-item-m1')));
    await tester.tap(find.byKey(const ValueKey('calendar-item-m1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
  });

  testWidgets('only a permitted member gets the Member chip', (tester) async {
    await pumpHub(tester, admin: false);
    expect(find.byKey(const ValueKey('calendar-member-chip')), findsNothing);
  });

  testWidgets('an admin can look at another member, and the query says who',
      (tester) async {
    final r = await pumpHub(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-member-chip')));
    await tester.tap(find.byKey(const ValueKey('calendar-member-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-member-member-2')));
    await tester.pumpAndSettle();
    expect(r.calendar.queries.last.memberId, 'member-2');
  });

  testWidgets('the shell shield opens who-can-see, with the log', (tester) async {
    final r = await pumpHub(tester);
    r.calendar.log.add(DataAccessEntry(
      id: 'a1',
      actorMemberId: 'member-2',
      subjectMemberId: 'member-1',
      category: 'finances',
      at: kTestNow,
    ));
    // #728 — the shield lives in the shell bar, left of the bell, on
    // every tab; who-can-see is the first row of Privacy & data.
    await tester.tap(find.byKey(const ValueKey('shell-privacy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy-who-can-see')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access-sheet')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('access-log-a1')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('access-sheet')),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.byKey(const ValueKey('access-log-a1')), findsOneWidget);
  });

  testWidgets('the feature OFF keeps the classic calendar', (tester) async {
    await pumpHub(tester, flags: const {'calendarHub': false});
    expect(find.byKey(const ValueKey('calendar-feed')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-date-button')), findsNothing);
  });
}
