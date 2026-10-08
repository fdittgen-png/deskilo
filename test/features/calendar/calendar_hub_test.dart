// SPDX-License-Identifier: AGPL-3.0-or-later
//
// THE CALENDAR HUB (#718): the calendar is a selector; what it selects
// is one feed of every dated fact the member may see, each row leading
// to its source. And the ACCESS rules (#719): a kind the server declines
// is shown as locked, never as an empty day.
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/domain/calendar_repository.dart';
import 'package:deskilo/features/money/providers/money_focus_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import '../../helpers/open_my_account.dart';
import '../../helpers/screens/calendar_hub.dart';

void main() {
  testWidgets('booking rows distinguish resources and keep deleted-source fallbacks', (tester) async {
    final env = await pumpHub(tester, size: const Size(800, 1100));
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    final plans = container.read(floorPlanRepositoryProvider) as FakeFloorPlanRepository;
    plans.seats.add(plans.seats.single.copyWith(id: 'seat-5', name: 'A2'));
    final reservations = container.read(reservationRepositoryProvider) as FakeReservationRepository;
    for (final (id, seat) in [('res-1', 'seat-4'), ('res-2', 'seat-5')]) {
      reservations.reservations.add(Reservation(id: id, workspaceId: 'ws-1',
          seatId: seat, memberId: 'member-1', startsAt: kTestNow,
          endsAt: kTestNow.add(const Duration(hours: 2)), status: ReservationStatus.reserved));
    }
    env.calendar.items.addAll([
      CalendarItem(kind: CalendarKind.reservation, id: 'r2', at: kTestNow,
          memberId: 'member-1', title: '', status: 'reserved', link: const ReservationLink('res-2')),
      CalendarItem(kind: CalendarKind.reservation, id: 'gone', at: kTestNow,
          memberId: 'member-1', title: '', link: const ReservationLink('missing')),
    ]);
    container.invalidate(reservationsForMonthProvider);
    container.invalidate(calendarItemsProvider);
    await tester.pumpAndSettle();
    for (final (id, name) in [('r1', 'A1'), ('r2', 'A2')]) {
      final row = find.byKey(ValueKey('calendar-item-$id'));
      expect(find.descendant(of: row, matching: find.textContaining('Ground floor')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.textContaining(name)), findsOneWidget);
    }
    expect(find.textContaining('Resource unavailable'), findsOneWidget);
    expect(find.textContaining('reserved'), findsOneWidget);
  });

  testWidgets('My bookings is visible and resets member and kind filters', (tester) async {
    final r = await pumpHub(tester);
    final shortcut = find.byKey(const ValueKey('calendar-my-bookings'));
    expect(shortcut.hitTestable(), findsOneWidget);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(r.calendar.queries.last.kinds, {CalendarKind.reservation});
    expect(r.calendar.queries.last.memberId, isNull);
    expect(find.byKey(const ValueKey('calendar-item-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-m1')), findsNothing);
    expect(find.text('Me · Bookings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-reset-filters')));
    await tester.pumpAndSettle();
    expect(r.calendar.queries.last.kinds, isNull);
    expect(r.calendar.queries.last.memberId, isNull);
  });

  testWidgets('today is selected and the feed shows every kind of the day',
      (tester) async {
    final r = await pumpHub(tester);

    expect(find.byKey(const ValueKey('calendar-feed')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-item-m1')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('calendar-item-p1')), 100,
        scrollable: find.descendant(of: find.byKey(const ValueKey('calendar-feed')), matching: find.byType(Scrollable)).first);
    expect(find.byKey(const ValueKey('calendar-item-p1')), findsOneWidget);
    // Yesterday's invoice is outside a one-day selection.
    expect(find.byKey(const ValueKey('calendar-item-i-old')), findsNothing);
    // The query the server got was a half-open day, for ME, all kinds.
    final q = r.calendar.queries.last;
    // #818 — the hub opens on the AGENDA: thirty days from today.
    expect(q.to.difference(q.from), const Duration(days: 30));
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
    await tester.scrollUntilVisible(find.byKey(const ValueKey('calendar-item-p1')), 100,
        scrollable: find.descendant(of: find.byKey(const ValueKey('calendar-feed')), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-item-p1')).hitTestable(), findsOneWidget);
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
    await tester.scrollUntilVisible(find.byKey(const ValueKey('calendar-item-m1')), 100,
        scrollable: find.descendant(of: find.byKey(const ValueKey('calendar-feed')), matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(find.byKey(const ValueKey('calendar-item-m1')));
    await tester.pumpAndSettle();
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
    // #728 — who-can-see is the first row of Privacy & data, which
    // #1823 moved from the shell's shield into Me.
    await openMyPrivacy(tester); // #1823: Privacy lives in Me
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
