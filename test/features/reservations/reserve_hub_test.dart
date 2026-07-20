// SPDX-License-Identifier: MIT
//
// #208 (epic #204): the Reserve hub behind the bottom bar's raised centre
// button — date-pill strip (+ calendar icon), granularity-aware window
// chips (half-day Morning/Afternoon/Full day per #201, from→to clock
// chips otherwise), and the Plan · Day · Week views. Plan mirrors the
// live-plan canvas for the selected window and books free seats via the
// shared BookingSheet (#206); Day reuses DayTimeline in everyone mode;
// Week is the seat × day occupancy grid of the selected day's ISO week
// (#236) with AM/PM half-slots and tappable day headers; closed days
// (#186) gate booking with the banner.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/core/ui/canvas_controls.dart';
import 'package:deskilo/features/calendar/presentation/widgets/day_timeline.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_screen.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/month_grid.dart';
import 'package:deskilo/features/reservations/presentation/widgets/week_grid.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import 'package:deskilo/core/time/workspace_time.dart';
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
  FakeReservationRepository? repo,
}) async {
  // Portrait viewport: these tests exercise the hub's feature behaviour,
  // not the landscape split (which is covered separately). The 800×600
  // default is landscape and would engage the side-panel layout.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) addSecondLevel(plans);
  final reservations = (repo ?? FakeReservationRepository())
    ..reservations.addAll(seed);
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
        5 * PlanCanvasMetrics.cellSize,
        4 * PlanCanvasMetrics.cellSize,
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

/// Day [index] (0 = Monday … 6 = Sunday) of today's ISO week — the
/// columns the Week grid shows when the hub opens.
DateTime _weekDay(int index) {
  final monday = WeekGrid.weekStartOf(_today);
  return DateTime(monday.year, monday.month, monday.day + index);
}

/// Fill color of one half-slot cell (null = empty outline slot).
Color? _cellFill(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(find.byKey(key));
  return (container.decoration as BoxDecoration?)?.color;
}

/// Theme brightness the grid renders under (drives SeatStateColors.of).
Brightness _gridBrightness(WidgetTester tester) => Theme.of(
      tester.element(find.byKey(const ValueKey('reserve-week-grid'))),
    ).brightness;

/// Whether [day]'s ISO week straddles a month boundary.
bool _weekStraddlesMonth(DateTime day) {
  final monday = WeekGrid.weekStartOf(day);
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  return monday.month != sunday.month;
}

/// [FakeReservationRepository] logging every month-shaped fetch window
/// (first-of-month → first-of-next-month) — asserts that the Week grid
/// watches BOTH month providers when its week straddles a boundary.
class _LoggingReservationRepository extends FakeReservationRepository {
  final monthFetches = <DateTime>[];

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    if (from.day == 1 &&
        from.hour == 0 &&
        from.minute == 0 &&
        to == DateTime(from.year, from.month + 1, 1)) {
      monthFetches.add(from);
    }
    return super.fetchWindow(workspaceId, from: from, to: to);
  }
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
  // Half-slot classification anchors to the WORKSPACE clock (the fake
  // workspace is Europe/Berlin); reset between tests.
  tearDown(WorkspaceTime.reset);

  testWidgets(
      'landscape splits the hub into a side panel + level (no overflow, the '
      'four-view toggle scales to fit)', (tester) async {
    await pumpHub(tester);
    // Rotate to a phone landscape after opening the hub.
    tester.view.physicalSize = const Size(760, 360);
    await tester.pumpAndSettle();

    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.byKey(const ValueKey('reserve-view-switch')), findsOneWidget);
    expect(find.byKey(_canvasKey), findsOneWidget);
  });

  test('hub metrics are pinned (contract of #208)', () {
    expect(ReserveHubMetrics.stripDayCount, 14);
    expect(ReserveHubMetrics.stripHeight, 58.0);
    expect(ReserveHubMetrics.datePickerRangeDays, 365);
    // Canvas geometry now lives in the shared PlanCanvasMetrics (one
    // source of truth for Plan tab, Reserve hub and editor).
    expect(PlanCanvasMetrics.cellSize, 14.0);
    expect(PlanCanvasMetrics.cells, 120);
    expect(CanvasControls.defaultMinScale, 0.4);
    expect(CanvasControls.defaultMaxScale, 3.0);
    expect(CanvasControls.defaultBoundaryMargin, 200.0);
    expect(ReserveHubMetrics.snapMinutes, 15);
    expect(ReserveHubMetrics.defaultStay, const Duration(hours: 4));
    expect(ReserveHubMetrics.lastSlotHour, 23);
    expect(ReserveHubMetrics.lastSlotMinute, 45);
  });

  test('week grid metrics are pinned (contract of #236)', () {
    expect(WeekGridMetrics.daysPerWeek, 7);
    expect(WeekGridMetrics.leadingWidth, 112.0);
    expect(WeekGridMetrics.headerHeight, 40.0);
    expect(WeekGridMetrics.rowHeight, 36.0);
    expect(WeekGridMetrics.groupHeaderRowHeight, 28.0);
    expect(WeekGridMetrics.levelHeaderRowHeight, 32.0);
    expect(WeekGridMetrics.minDayWidth, 44.0);
    expect(WeekGridMetrics.cellInset, 3.0);
    expect(WeekGridMetrics.halfSlotGap, 2.0);
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
      'full-day workspace: only the Day chip — no half chips, no clock '
      'chips (0032)', (tester) async {
    await pumpHub(tester, granularity: BookingGranularity.fullDay);

    expect(find.byKey(_dayChip), findsOneWidget);
    expect(find.byKey(_amChip), findsNothing);
    expect(find.byKey(_pmChip), findsNothing);
    expect(find.byKey(_fromChip), findsNothing);
    expect(find.byKey(_toChip), findsNothing);
  });

  testWidgets('minute-slot workspace books via from→to clock chips (0032)',
      (tester) async {
    await pumpHub(tester, granularity: BookingGranularity.minutes30);

    expect(find.byKey(_fromChip), findsOneWidget);
    expect(find.byKey(_toChip), findsOneWidget);
    expect(find.byKey(_dayChip), findsNothing);
  });

  testWidgets(
      'the bottom bar and its centre button stay visible and active on '
      'the hub', (tester) async {
    await pumpHub(tester);

    // The hub is a shell branch — the bar never disappears.
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.byTooltip('Reserve'), findsOneWidget);

    // Bar destinations keep working from the hub…
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.byKey(_canvasKey), findsNothing);

    // …and the centre button brings the hub straight back.
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();
    expect(find.byKey(_canvasKey), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'From'),
        matching: find.text('09:00'),
      ),
      findsOneWidget,
    );

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

    // The period is editable via the chips (half-day config), no free
    // 'Until'.
    expect(find.byKey(const ValueKey('booking-am')), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Until'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    // The canonical window anchors to the WORKSPACE clock (the fake
    // workspace is Europe/Berlin) — assert the instants, not device
    // wall-clock.
    final expected = HalfDayWindows.morning(_today);
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
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
      'Week view is the seat × day grid (#236): seven tappable day headers '
      "Mon–Sun of the selected day's ISO week, a half-slot pair per day on "
      'the seat row, and no pager', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reserve-week-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('reserve-week-pager')), findsNothing);
    expect(find.byType(DayTimeline), findsNothing);

    expect(_weekDay(0).weekday, DateTime.monday);
    expect(_weekDay(6).weekday, DateTime.sunday);
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(WeekGrid.dayHeaderKey(_weekDay(i))), findsOneWidget);
      expect(
        find.byKey(WeekGrid.cellKey('seat-4', _weekDay(i), morning: true)),
        findsOneWidget,
      );
      expect(
        find.byKey(WeekGrid.cellKey('seat-4', _weekDay(i), morning: false)),
        findsOneWidget,
      );
    }
  });

  testWidgets(
      'half-slot occupancy: a 01:15–05:15 booking of mine colors that '
      "day's AM half in the mine tone and leaves PM an empty outline",
      (tester) async {
    // Tuesday of the current week — past days still render occupancy.
    // Seeds anchor to the workspace clock: the grid classifies halves
    // against workspace-local windows whatever the device zone.
    WorkspaceTime.install('Europe/Berlin');
    final tuesday = _weekDay(1);
    await pumpHub(
      tester,
      seed: [
        Reservation(
          id: 'res-am',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: WorkspaceTime.at(
              tuesday.year, tuesday.month, tuesday.day, 1, 15),
          endsAt: WorkspaceTime.at(
              tuesday.year, tuesday.month, tuesday.day, 5, 15),
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final brightness = _gridBrightness(tester);
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', tuesday, morning: true)),
      SeatStateColors.of(SeatState.mine, brightness: brightness),
    );
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', tuesday, morning: false)),
      isNull,
    );
  });

  testWidgets(
      "half-slot occupancy: another member's 15:00–19:00 colors PM only in "
      'the occupied tone; a full-day booking colors both halves',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final wednesday = _weekDay(2);
    final thursday = _weekDay(3);
    await pumpHub(
      tester,
      seed: [
        Reservation(
          id: 'res-pm',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: WorkspaceTime.at(
              wednesday.year, wednesday.month, wednesday.day, 15),
          endsAt: WorkspaceTime.at(
              wednesday.year, wednesday.month, wednesday.day, 19),
          status: ReservationStatus.reserved,
        ),
        Reservation(
          id: 'res-full',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: WorkspaceTime.at(
              thursday.year, thursday.month, thursday.day),
          endsAt: WorkspaceTime.at(
              thursday.year, thursday.month, thursday.day + 1),
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final brightness = _gridBrightness(tester);
    final occupied =
        SeatStateColors.of(SeatState.reserved, brightness: brightness);
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', wednesday, morning: true)),
      isNull,
    );
    expect(
      _cellFill(
        tester,
        WeekGrid.cellKey('seat-4', wednesday, morning: false),
      ),
      occupied,
    );
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', thursday, morning: true)),
      occupied,
    );
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', thursday, morning: false)),
      occupied,
    );
  });

  testWidgets(
      'tapping a day header selects that day AND switches the hub to the '
      'Day view', (tester) async {
    await pumpHub(tester);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // A neighbouring day inside the same ISO week (Sundays step back).
    final today = _today;
    final target = today.weekday < DateTime.sunday
        ? DateTime(today.year, today.month, today.day + 1)
        : DateTime(today.year, today.month, today.day - 1);
    await tester.tap(find.byKey(WeekGrid.dayHeaderKey(target)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reserve-day-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('reserve-week-grid')), findsNothing);
    final timeline = tester.widget<DayTimeline>(find.byType(DayTimeline));
    expect(DateUtils.isSameDay(timeline.day, target), isTrue);
    // The strip follows too (only future days have a pill — the strip
    // starts today).
    if (!target.isBefore(today)) {
      expect(chipSelected(tester, ReserveScreen.dayPillKey(target)), isTrue);
    }
  });

  testWidgets(
      'tapping an occupied cell lists that seat/day\'s reservations '
      '("09:00 – 11:00 · Flo" in everyone mode) with tap-through to my '
      'detail sheet', (tester) async {
    // Workspace-clock seeds: one AM booking of mine, one PM of Ana's —
    // the AM half is OCCUPIED, so its tap lists occupants (a free half
    // would book instead, see the free-slot test).
    WorkspaceTime.install('Europe/Berlin');
    final today = _today;
    await pumpHub(
      tester,
      seed: [
        Reservation(
          id: 'res-own',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: WorkspaceTime.at(today.year, today.month, today.day, 9),
          endsAt: WorkspaceTime.at(today.year, today.month, today.day, 11),
          status: ReservationStatus.reserved,
        ),
        Reservation(
          id: 'res-ana',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: WorkspaceTime.at(today.year, today.month, today.day, 14),
          endsAt: WorkspaceTime.at(today.year, today.month, today.day, 16),
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(WeekGrid.cellKey('seat-4', today, morning: true)));
    await tester.pumpAndSettle();

    // The whole day's occupants, times + names (everyone mode), on the
    // workspace wall clock.
    expect(find.text('09:00 – 11:00 · Flo'), findsOneWidget);
    expect(find.text('14:00 – 16:00 · Ana'), findsOneWidget);

    // Tap-through on MY reservation opens the shared detail sheet.
    await tester.tap(find.byKey(WeekGrid.sheetItemKey('res-own')));
    await tester.pumpAndSettle();
    expect(
      find.text('Ground floor · Main room · Window desk · A1'),
      findsOneWidget,
    );
    expect(find.text('Show on plan'), findsOneWidget);
  });

  testWidgets(
      "Week view with All levels stacks every level's seat rows under "
      'level headers (#221 semantics)', (tester) async {
    await pumpHub(tester, twoLevels: true);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'All levels').first);
    await tester.pumpAndSettle();

    expect(find.byKey(WeekGrid.levelHeaderKey('level-1')), findsOneWidget);
    expect(find.byKey(WeekGrid.levelHeaderKey('level-9')), findsOneWidget);
    final monday = _weekDay(0);
    expect(
      find.byKey(WeekGrid.cellKey('seat-4', monday, morning: true)),
      findsOneWidget,
    );
    expect(
      find.byKey(WeekGrid.cellKey('seat-9', monday, morning: true)),
      findsOneWidget,
    );
  });

  testWidgets(
      'a week straddling a month boundary fetches BOTH month windows and '
      'renders the cross-month reservation', (tester) async {
    // First day from today whose ISO week straddles a month boundary
    // (always within ~2 months of any run date).
    var target = _today;
    while (!_weekStraddlesMonth(target)) {
      target = DateTime(target.year, target.month, target.day + 1);
    }
    final monday = WeekGrid.weekStartOf(target);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    // The week day on the OTHER side of the boundary from [target].
    final crossDay = monday.month == target.month ? sunday : monday;
    final repo = _LoggingReservationRepository();
    WorkspaceTime.install('Europe/Berlin');
    await pumpHub(
      tester,
      repo: repo,
      seed: [
        Reservation(
          id: 'res-cross',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: WorkspaceTime.at(
              crossDay.year, crossDay.month, crossDay.day, 9),
          endsAt: WorkspaceTime.at(
              crossDay.year, crossDay.month, crossDay.day, 12),
          status: ReservationStatus.reserved,
        ),
      ],
    );

    // Steer the hub to [target] via the calendar icon (it may lie beyond
    // the strip and in a later month).
    await tester.tap(find.byKey(const ValueKey('reserve-date-button')));
    await tester.pumpAndSettle();
    var monthsAhead = (target.year - _today.year) * 12 +
        target.month -
        _today.month;
    while (monthsAhead-- > 0) {
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

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // Both months around the boundary were fetched (month providers).
    expect(
      repo.monthFetches.toSet(),
      containsAll({
        DateTime(monday.year, monday.month),
        DateTime(sunday.year, sunday.month),
      }),
    );
    // And the reservation on the other month's side is drawn.
    expect(
      _cellFill(tester, WeekGrid.cellKey('seat-4', crossDay, morning: true)),
      SeatStateColors.of(
        SeatState.mine,
        brightness: _gridBrightness(tester),
      ),
    );
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

  testWidgets(
      'Month view: availability calendar shows free desks per day and '
      'today; a fully-booked day reads 0 free (#7)', (tester) async {
    // Seeds anchor to the workspace clock (fake workspace = Berlin, which
    // the shell installs), so the day windows and the seed agree.
    WorkspaceTime.install('Europe/Berlin');
    final today = _today;
    final fullDay = HalfDayWindows.fullDay(today);
    await pumpHub(
      tester,
      seed: [
        // The one seeded desk is taken all of today → 0 free.
        Reservation(
          id: 'res-full',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: fullDay.start,
          endsAt: fullDay.end,
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.byType(MonthGrid), findsOneWidget);
    // Today's cell: 0 of 1 desk free.
    final todayCell = find.descendant(
      of: find.byKey(MonthGrid.cellKey(today)),
      matching: find.text('0/1'),
    );
    expect(todayCell, findsOneWidget);
    // A free day (tomorrow) shows the full desk count.
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    if (tomorrow.month == today.month) {
      expect(
        find.descendant(
          of: find.byKey(MonthGrid.cellKey(tomorrow)),
          matching: find.text('1/1'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Month view: tapping a day drops into the Day view (#7)',
      (tester) async {
    final today = _today;
    // Pick an in-month day that is not today.
    final other = today.day == 1
        ? DateTime(today.year, today.month, 2)
        : DateTime(today.year, today.month, 1);
    await pumpHub(tester);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MonthGrid.cellKey(other)));
    await tester.pumpAndSettle();

    // Landed on the Day view for the tapped day.
    expect(find.byType(DayTimeline), findsOneWidget);
    expect(find.byType(MonthGrid), findsNothing);
  });

  testWidgets(
      'Week view: a FREE half-slot books it — tapping the AM cell under '
      'half-day granularity reserves exactly the morning window',
      (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final today = _today;
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(
      'week-free-seat-4-${WeekGrid.dayStampOf(today)}-am',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(BookingSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    final expected = HalfDayWindows.morning(today);
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
  });

  testWidgets(
      'Week view: an occupied half-slot names its occupant with an '
      'initial (everyone mode)', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final today = _today;
    await pumpHub(
      tester,
      seed: [
        Reservation(
          id: 'res-ana',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: WorkspaceTime.at(today.year, today.month, today.day, 9),
          endsAt: WorkspaceTime.at(today.year, today.month, today.day, 11),
          status: ReservationStatus.reserved,
        ),
      ],
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(WeekGrid.cellKey('seat-4', today, morning: true)),
        matching: find.text('A'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'Day view is an availability surface: seat rows render on an empty '
      'day and a free-row tap books the selected window', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final repo = await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
    );

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    // No reservations — but the seat row is there, not an empty hint.
    expect(find.text('A1'), findsOneWidget);
    expect(
      find.text('No reservations on this level for this day.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('timeline-free-seat-4')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    // Default hub window under half-day granularity = the full day.
    final created = repo.reservations.single;
    final expected = HalfDayWindows.fullDay(_today);
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
  });

  testWidgets(
      'honest controls: the window chips show on Plan and Day, never on '
      'Week or Month', (tester) async {
    await pumpHub(tester, granularity: BookingGranularity.halfDay);

    expect(find.byKey(_amChip), findsOneWidget); // Plan view

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.byKey(_amChip), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.byKey(_amChip), findsNothing);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.byKey(_amChip), findsNothing);
  });
}
