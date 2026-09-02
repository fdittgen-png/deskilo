// SPDX-License-Identifier: 0BSD
//
// #818 — the Calendar tab as three views over the hub's feed: the
// AGENDA (from today, thirty days), the WEEK (a strip of pills) and the
// MONTH (a compact grid). Markers by group, closed days drawn as closed,
// relative day headers, and the two new dated kinds.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/features/calendar/presentation/calendar_view.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_week_strip.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_calendar_repository.dart';
import '../../helpers/mock_providers.dart';

CalendarItem _item(CalendarKind kind, String id, DateTime at,
        {int? cents}) =>
    CalendarItem(
      kind: kind,
      id: id,
      at: at,
      memberId: 'member-1',
      title: kind == CalendarKind.due ? 'INV-1' : 'Desk A1',
      amountCents: cents,
      currency: 'EUR',
      link: const ReservationLink('res-1'),
    );

DateTime _utc(DateTime day, int hour) =>
    DateTime.utc(day.year, day.month, day.day, hour);

Future<FakeCalendarRepository> pumpViews(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  List<ClosureDay> closures = const [],
}) async {
  final today = kTestNow;
  final tomorrow = today.add(const Duration(days: 1));
  final nextWeek = today.add(const Duration(days: 8));
  final calendar = FakeCalendarRepository()
    ..items.addAll([
      _item(CalendarKind.reservation, 'r-today', _utc(today, 9)),
      _item(CalendarKind.message, 'm-tomorrow', _utc(tomorrow, 10)),
      _item(CalendarKind.due, 'due-next', _utc(nextWeek, 12), cents: 25000),
      _item(CalendarKind.scheduled, 'sch-next', _utc(nextWeek, 8),
          cents: -1200),
      // Far ahead: outside the agenda's thirty days.
      _item(CalendarKind.invoice, 'i-far',
          _utc(today.add(const Duration(days: 45)), 12)),
    ]);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo'}
    ..openWeekdays['ws-1'] = openWeekdays
    ..closureDays.addAll(closures);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(calendar: calendar, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return calendar;
}

void main() {
  group('the selection arithmetic', () {
    final wed = DateTime(2026, 9, 2); // a Wednesday
    test('agenda: thirty days from the anchor, stepping by thirty', () {
      final s = CalendarSelection(view: CalendarView.agenda, anchor: wed);
      expect(s.from, wed);
      expect(s.to, DateTime(2026, 10, 2));
      expect(s.shifted(1).anchor, DateTime(2026, 10, 2));
      expect(s.shifted(-1).anchor, DateTime(2026, 8, 3));
    });
    test('week: Monday to Sunday around the anchor', () {
      final s = CalendarSelection(view: CalendarView.week, anchor: wed);
      expect(s.weekStart, DateTime(2026, 8, 31));
      expect(s.to, DateTime(2026, 9, 7));
      expect(s.shifted(1).weekStart, DateTime(2026, 9, 7));
    });
    test('month: one day for the feed, the whole month for the markers, '
        'and the day of month survives a step where it can', () {
      final s = CalendarSelection(view: CalendarView.month, anchor: DateTime(2026, 8, 31));
      expect(s.from, DateTime(2026, 8, 31));
      expect(s.to, DateTime(2026, 9, 1));
      expect(s.monthStart, DateTime(2026, 8));
      expect(s.monthEnd, DateTime(2026, 9));
      expect(s.shifted(1).anchor, DateTime(2026, 9, 30));
      expect(s.shifted(-1).anchor, DateTime(2026, 7, 31));
    });
    test('relative days', () {
      expect(relativeDayOf(wed, wed), RelativeDay.today);
      expect(relativeDayOf(DateTime(2026, 9, 3), wed), RelativeDay.tomorrow);
      expect(relativeDayOf(DateTime(2026, 9, 1), wed), RelativeDay.yesterday);
      expect(relativeDayOf(DateTime(2026, 9, 5), wed), isNull);
    });
    test('the groups: every kind belongs to exactly one', () {
      for (final kind in CalendarKind.values) {
        expect(CalendarGroup.values, contains(kind.group));
      }
      expect(CalendarKind.due.isMoney, isTrue);
      expect(CalendarKind.scheduled.isMoney, isTrue);
      expect(CalendarKind.due.group, CalendarGroup.money);
      expect(CalendarKind.reminder.group, CalendarGroup.bookings);
    });
  });

  group('on screen', () {
    testWidgets(
        'the agenda is the default: thirty days from today, relative '
        'headers, the far-off invoice stays out', (tester) async {
      final calendar = await pumpViews(tester);
      expect(find.byKey(const ValueKey('calendar-view-switch')), findsOneWidget);
      final q = calendar.queries.last;
      expect(q.to.difference(q.from), const Duration(days: calendarAgendaDays));
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsOneWidget);
      expect(find.textContaining('Today ·'), findsOneWidget);
      expect(find.textContaining('Tomorrow ·'), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-item-i-far')), findsNothing);
      // The two new kinds are in the feed, worded.
      await tester.ensureVisible(find.byKey(const ValueKey('calendar-item-due-next')));
      expect(find.textContaining('Payment due · INV-1'), findsOneWidget);
      expect(find.textContaining('Scheduled expense ·'), findsOneWidget);
    });

    testWidgets('the arrows step the agenda by thirty days; Today jumps back',
        (tester) async {
      final calendar = await pumpViews(tester);
      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await tester.pumpAndSettle();
      expect(calendar.queries.last.from.difference(calendar.queries.first.from),
          const Duration(days: calendarAgendaDays));
      expect(find.byKey(const ValueKey('calendar-item-i-far')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calendar-today')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsOneWidget);
    });

    testWidgets('the month view: a grid with markers by group, the closed '
        'day muted, a tap loads that day only', (tester) async {
      final today = kTestNow;
      final tomorrow = today.add(const Duration(days: 1));
      final calendar = await pumpViews(
        tester,
        closures: [
          ClosureDay(
            id: 'c',
            workspaceId: 'ws-1',
            day: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
            reason: 'Holiday',
          ),
        ],
      );
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-month-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-legend')), findsOneWidget);
      // ONE query for the whole month feeds the markers and the day.
      final q = calendar.queries.last;
      expect(q.to.difference(q.from).inDays, greaterThanOrEqualTo(28));
      expect(
        find.byKey(ValueKey('calendar-marker-${today.day}-bookings')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('calendar-marker-${tomorrow.day}-activity')),
        findsOneWidget,
      );
      // The selected day (today) shows only its own rows.
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-item-m-tomorrow')), findsNothing);
      // Tap tomorrow: its row, and the closed banner with the reason.
      await tester.tap(find.byKey(CalendarMonthGrid.cellKey(tomorrow)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-item-m-tomorrow')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsNothing);
      expect(find.textContaining('Closed — Holiday'), findsOneWidget);
    });

    testWidgets('the week view: seven pills with counts, the week loaded',
        (tester) async {
      final today = kTestNow;
      final calendar = await pumpViews(tester);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-week-strip')), findsOneWidget);
      final q = calendar.queries.last;
      expect(q.to.difference(q.from), const Duration(days: 7));
      expect(find.byKey(CalendarWeekStrip.pillKey(today)), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsOneWidget);
    });

    testWidgets('a closed weekday in the week reads closed in the feed',
        (tester) async {
      final today = kTestNow;
      final closedWeekday = today.weekday == 7 ? 1 : today.weekday + 1;
      await pumpViews(
        tester,
        openWeekdays: [for (var d = 1; d <= 7; d++) if (d != closedWeekday) d],
      );
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('Closed'), findsWidgets);
    });

    testWidgets('flag OFF keeps the plain day/range selector', (tester) async {
      await pumpViews(tester, flags: const {'calendarViews': false});
      expect(find.byKey(const ValueKey('calendar-view-switch')), findsNothing);
      expect(find.byKey(const ValueKey('calendar-range-toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-item-r-today')), findsOneWidget);
    });
  });

  test('migration 0145 adds the two kinds to calendar_items in place', () {
    final sql = File('supabase/migrations/0145_calendar_due_dates.sql')
        .readAsStringSync();
    expect(sql, contains("p.proname = 'calendar_items'"));
    expect(sql, contains("'due','scheduled'"));
    expect(sql, contains("'kind', 'due'"));
    expect(sql, contains("'kind', 'scheduled'"));
    expect(sql, contains('first_after_days'));
    expect(sql, contains("o.status in ('awaiting_member','pending_validation')"));
    for (final kind in [CalendarKind.due, CalendarKind.scheduled]) {
      expect(sql, contains("'${kind.wire}'"));
    }
  });
}
