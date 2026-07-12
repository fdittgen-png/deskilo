// SPDX-License-Identifier: MIT
//
// #208 (epic #204): the Reserve hub behind the bottom bar's raised centre
// button — date-pill strip (+ calendar icon), granularity-aware window
// chips (half-day Morning/Afternoon/Full day per #201, from→to clock
// chips otherwise), and the Plan · Day · Week views. Plan mirrors the
// live-plan canvas for the selected window and books free seats via the
// shared BookingSheet (#206); Day/Week reuse DayTimeline in everyone
// mode; closed days (#186) gate booking with the banner.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/calendar/presentation/widgets/day_timeline.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../calendar/day_timeline_test.dart' show addSecondLevel;
import '../plan/time_scroller_test.dart' show pickChipTime;

const _amChip = ValueKey('reserve-am-chip');
const _pmChip = ValueKey('reserve-pm-chip');
const _dayChip = ValueKey('reserve-day-chip');
const _fromChip = ValueKey('reserve-from-chip');
const _toChip = ValueKey('reserve-to-chip');
const _canvasKey = ValueKey('reserve-plan-canvas');

/// Pumps the app and enters the Reserve hub through the bar's raised
/// centre button (#207), on the seeded small plan (one seat 'A1' =
/// seat-4 at grid (2,2)). Open every day by default so booking flows
/// never hit the closed-day gate (#186) — pass [openWeekdays] to test it.
Future<FakeReservationRepository> pumpHub(
  WidgetTester tester, {
  List<Reservation> seed = const [],
  BookingGranularity? granularity,
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  bool twoLevels = false,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) addSecondLevel(plans);
  final reservations = FakeReservationRepository()..reservations.addAll(seed);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..openWeekdays['ws-1'] = openWeekdays;
  if (granularity != null) {
    workspace.bookingGranularities['ws-1'] = granularity;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Reserve'));
  await tester.pumpAndSettle();
  return reservations;
}

/// Centre of seat 'A1' on the hub's canvas (footprint (2,2)..(8,6)).
Offset seatCenter(WidgetTester tester) {
  final canvas = tester.getTopLeft(find.byKey(_canvasKey));
  return canvas +
      const Offset(
        5 * ReserveHubMetrics.canvasCellSize,
        4 * ReserveHubMetrics.canvasCellSize,
      );
}

/// The painter of the hub's plan canvas.
FloorPlanPainter hubPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.byKey(_canvasKey));
  return paint.painter! as FloorPlanPainter;
}

/// Whether the [ChoiceChip] under [key] renders as selected.
bool chipSelected(WidgetTester tester, Key key) =>
    tester.widget<ChoiceChip>(find.byKey(key)).selected;

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// A reservation on the seeded seat covering [day] [startHour]–[endHour].
Reservation reservationOn(
  DateTime day, {
  required String id,
  String memberId = 'member-1',
  int startHour = 9,
  int endHour = 11,
}) {
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: memberId,
    startsAt: DateTime(day.year, day.month, day.day, startHour),
    endsAt: DateTime(day.year, day.month, day.day, endHour),
    status: ReservationStatus.reserved,
  );
}

void main() {
  test('hub metrics are pinned (contract of #208)', () {
    expect(ReserveHubMetrics.stripDayCount, 14);
    expect(ReserveHubMetrics.stripHeight, 76.0);
    expect(ReserveHubMetrics.datePickerRangeDays, 365);
    expect(ReserveHubMetrics.weekPageCount, 365);
    expect(ReserveHubMetrics.canvasCellSize, 14.0);
    expect(ReserveHubMetrics.canvasCells, 120);
    expect(ReserveHubMetrics.canvasMinScale, 0.4);
    expect(ReserveHubMetrics.canvasMaxScale, 3.0);
    expect(ReserveHubMetrics.canvasBoundaryMargin, 200.0);
    expect(ReserveHubMetrics.snapMinutes, 15);
    expect(ReserveHubMetrics.defaultStay, const Duration(hours: 4));
    expect(ReserveHubMetrics.lastSlotHour, 23);
    expect(ReserveHubMetrics.lastSlotMinute, 45);
  });

  testWidgets(
      'the centre button opens the hub: date strip with today selected, '
      'from/to chips on a flexible workspace, Plan view by default',
      (tester) async {
    await pumpHub(tester);

    // Full-screen route over the shell, titled like the button.
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Reserve'),
    );
    expect(appBarTitle, findsOneWidget);

    // Date strip: today's pill exists and is selected.
    final todayPill = find.byKey(ReserveScreen.dayPillKey(_today));
    expect(todayPill, findsOneWidget);
    expect(chipSelected(tester, ReserveScreen.dayPillKey(_today)), isTrue);
    expect(find.byKey(const ValueKey('reserve-date-button')), findsOneWidget);

    // Flexible granularity: from→to clock chips, no half-day chips.
    expect(find.byKey(_fromChip), findsOneWidget);
    expect(find.byKey(_toChip), findsOneWidget);
    expect(find.byKey(_amChip), findsNothing);
    expect(find.byKey(_pmChip), findsNothing);
    expect(find.byKey(_dayChip), findsNothing);

    // Plan · Day · Week switch with the plan canvas as the default view.
    expect(find.byKey(const ValueKey('reserve-view-switch')), findsOneWidget);
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byType(DayTimeline), findsNothing);
  });

  testWidgets(
      'flexible workspace: picking a 09:00–12:00 window and tapping the '
      'free seat books exactly that window through the shared sheet, and '
      'the canvas refreshes to mine (providers invalidated)',
      (tester) async {
    final repo = await pumpHub(tester);

    await pickChipTime(tester, 'reserve-from-chip', hour: '9', minute: '00');
    await pickChipTime(tester, 'reserve-to-chip', hour: '12', minute: '00');

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.byType(BookingSheet), findsOneWidget);
    expect(find.textContaining('Starts at 09:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    expect(created.seatId, 'seat-4');
    expect(created.status, ReservationStatus.reserved);
    expect(created.checkedInAt, isNull);
    final today = _today;
    expect(
      created.startsAt.toLocal(),
      DateTime(today.year, today.month, today.day, 9),
    );
    expect(
      created.endsAt.toLocal(),
      DateTime(today.year, today.month, today.day, 12),
    );

    // invalidateBookingData refetched the day: the seat now renders mine.
    expect(hubPainter(tester).seatStates?['seat-4'], SeatState.mine);
  });

  testWidgets(
      'half-day workspace: Morning/Afternoon/Full day chips (full day '
      'preselected), booking Morning lands the canonical 00:00–13:00 with '
      'no Until tile', (tester) async {
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
    );

    expect(find.byKey(_amChip), findsOneWidget);
    expect(find.byKey(_pmChip), findsOneWidget);
    expect(find.byKey(_dayChip), findsOneWidget);
    expect(find.byKey(_fromChip), findsNothing);
    expect(find.byKey(_toChip), findsNothing);
    // The hub always browses a window: full day is the default here.
    expect(chipSelected(tester, _dayChip), isTrue);

    await tester.tap(find.byKey(_amChip));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, _amChip), isTrue);
    expect(chipSelected(tester, _dayChip), isFalse);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts at 00:00'), findsOneWidget);
    // Fixed end under half-day granularity (#201): no Until affordance.
    expect(find.widgetWithText(ListTile, 'Until'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    final today = _today;
    expect(created.startsAt.toLocal(), today);
    expect(
      created.endsAt.toLocal(),
      DateTime(today.year, today.month, today.day, HalfDayWindows.pivotHour),
    );
  });

  testWidgets(
      "Day view shows everyone's bookings with occupant names; tapping my "
      'own block opens the reservation detail sheet', (tester) async {
    final today = _today;
    await pumpHub(
      tester,
      seed: [
        reservationOn(today, id: 'res-own'),
        reservationOn(
          today,
          id: 'res-ana',
          memberId: 'member-2',
          startHour: 12,
          endHour: 14,
        ),
      ],
    );

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    // Everyone mode: the foreign block is visible and labelled.
    expect(find.byKey(DayTimeline.blockKey('res-ana')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);

    await tester.tap(find.byKey(DayTimeline.blockKey('res-own')));
    await tester.pumpAndSettle();

    expect(
      find.text('Ground floor · Main room · Window desk · A1'),
      findsOneWidget,
    );
    expect(find.text('Show on plan'), findsOneWidget);
  });

  testWidgets(
      'Week view: a swipe moves the selected day pill (two-way sync) and '
      "tomorrow's page shows tomorrow's reservation; a pill tap moves the "
      'pager', (tester) async {
    final today = _today;
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final later = DateTime(today.year, today.month, today.day + 2);
    await pumpHub(
      tester,
      seed: [
        reservationOn(tomorrow, id: 'res-tmrw'),
        reservationOn(later, id: 'res-later', startHour: 14, endHour: 16),
      ],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reserve-week-pager')), findsOneWidget);

    // Swipe to tomorrow: pager → strip sync.
    await tester.drag(
      find.byKey(const ValueKey('reserve-week-pager')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(chipSelected(tester, ReserveScreen.dayPillKey(tomorrow)), isTrue);
    expect(chipSelected(tester, ReserveScreen.dayPillKey(today)), isFalse);
    expect(find.byKey(DayTimeline.blockKey('res-tmrw')), findsOneWidget);

    // Tap the day-after-tomorrow pill: strip → pager sync.
    await tester.tap(find.byKey(ReserveScreen.dayPillKey(later)));
    await tester.pumpAndSettle();

    expect(chipSelected(tester, ReserveScreen.dayPillKey(later)), isTrue);
    expect(find.byKey(DayTimeline.blockKey('res-later')), findsOneWidget);
    expect(find.byKey(DayTimeline.blockKey('res-tmrw')), findsNothing);
  });

  testWidgets(
      'Week view with All levels selected still swipes to the next day '
      '(#221)', (tester) async {
    final today = _today;
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    await pumpHub(
      tester,
      twoLevels: true,
      seed: [reservationOn(tomorrow, id: 'res-tmrw')],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'All levels').first);
    await tester.pumpAndSettle();

    // All-levels mode is live on today's (empty) page.
    expect(
      find.text('No reservations on any level for this day.'),
      findsOneWidget,
    );

    // The pager still swipes with All selected (like the empty-page swipe
    // above — a page WITH timeline content owns horizontal drags either
    // way, all-levels or not).
    await tester.drag(
      find.byKey(const ValueKey('reserve-week-pager')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(chipSelected(tester, ReserveScreen.dayPillKey(tomorrow)), isTrue);
    expect(find.byKey(DayTimeline.blockKey('res-tmrw')), findsOneWidget);
  });

  testWidgets(
      'the calendar icon picks a day for the hub (beyond-the-strip path)',
      (tester) async {
    await pumpHub(tester);

    await tester.tap(find.byKey(const ValueKey('reserve-date-button')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final DateTime target;
    if (now.day < 28) {
      target = DateTime(now.year, now.month, now.day + 1);
    } else {
      // Month-end runs: the 1st of the next month keeps the pick valid
      // (firstDate is today).
      target = DateTime(now.year, now.month + 1, 1);
      await tester.tap(find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byTooltip('Next month'),
      ));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('${target.day}'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Observable regardless of whether the day still has a strip pill:
    // the Day view timeline is on the picked day.
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    final timeline = tester.widget<DayTimeline>(find.byType(DayTimeline));
    expect(DateUtils.isSameDay(timeline.day, target), isTrue);
  });

  testWidgets(
      'closed Saturday (Mon–Fri workspace): banner shown, seats muted and '
      'the seat tap is gated with the closed-day snackbar, no sheet',
      (tester) async {
    await pumpHub(tester, openWeekdays: const [1, 2, 3, 4, 5]);

    var saturday = _today;
    while (saturday.weekday != DateTime.saturday) {
      saturday =
          DateTime(saturday.year, saturday.month, saturday.day + 1);
    }
    await tester.tap(find.byKey(ReserveScreen.dayPillKey(saturday)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reserve-closed-banner')),
      findsOneWidget,
    );
    expect(hubPainter(tester).seatStates?['seat-4'], SeatState.blocked);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.byType(BookingSheet), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Closed on this day'),
      ),
      findsOneWidget,
    );
  });
}
