// SPDX-License-Identifier: MIT
//
// #201 (epic #199): under half-day booking granularity the plan header
// swaps the from→to time chips for Morning / Afternoon / Day choice
// chips, seat taps book exactly the canonical windows (00:00–13:00,
// 13:00–24:00, 00:00–24:00 workspace-local), walk-ups end at the current
// half-day boundary, and the booking sheet's "Until" affordance
// disappears (the end is fixed). Flexible workspaces keep the old chips.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import 'plan_closed_day_test.dart' show ThrowingReservationRepository;
import 'plan_screen_test.dart' show pumpPlan, seatCenter;
import 'time_scroller_test.dart' show planPainter;

const _amChip = ValueKey('plan-am-chip');
const _pmChip = ValueKey('plan-pm-chip');
const _dayChip = ValueKey('plan-day-chip');
const _fromChip = ValueKey('plan-from-chip');
const _toChip = ValueKey('plan-to-chip');

/// Pumps the Plan tab with the seeded small plan (one seat 'A1'/seat-4)
/// on a workspace whose booking granularity is half-day (#201). Open
/// every weekday so booking flows never hit the closed-day gate (#186).
Future<FakeReservationRepository> pumpHalfDayPlan(
  WidgetTester tester, {
  FakeReservationRepository? reservations,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservationRepo = reservations ?? FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7]
    ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservationRepo,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
  return reservationRepo;
}

/// Whether the [ChoiceChip] under [key] renders as selected.
bool chipSelected(WidgetTester tester, Key key) =>
    tester.widget<ChoiceChip>(find.byKey(key)).selected;

/// A foreign checked-in reservation on seat-4 covering today's local
/// [startHour]:00–[endHour]:00.
Reservation reservationToday({required int startHour, required int endHour}) {
  // Workspace-clock instants: the canonical windows the chips browse are
  // workspace-anchored, so the seeds must be too.
  final today = WorkspaceTime.dateOf(DateTime.now());
  return Reservation(
    id: 'res-$startHour',
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-2',
    startsAt: WorkspaceTime.at(today.year, today.month, today.day, startHour),
    endsAt: WorkspaceTime.at(today.year, today.month, today.day, endHour),
    status: ReservationStatus.checkedIn,
  );
}

void main() {
  // Windows anchor to the WORKSPACE clock (fake workspace =
  // Europe/Berlin) whatever zone the device runs in.
  setUp(() => WorkspaceTime.install('Europe/Berlin'));
  tearDown(WorkspaceTime.reset);

  testWidgets(
      'half-day workspace: Morning/Afternoon/Day chips replace the '
      'from/to time chips', (tester) async {
    await pumpHalfDayPlan(tester);

    expect(find.byKey(_amChip), findsOneWidget);
    expect(find.byKey(_pmChip), findsOneWidget);
    expect(find.byKey(_dayChip), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.byKey(_fromChip), findsNothing);
    expect(find.byKey(_toChip), findsNothing);
    // Live mode: no window selected yet.
    expect(chipSelected(tester, _amChip), isFalse);
    expect(chipSelected(tester, _pmChip), isFalse);
    expect(chipSelected(tester, _dayChip), isFalse);
  });

  testWidgets(
      'flexible workspace keeps the from/to chips — no half-day chips',
      (tester) async {
    // pumpPlan's default fake leaves the granularity unseeded = flexible.
    await pumpPlan(tester);

    expect(find.byKey(_fromChip), findsOneWidget);
    expect(find.byKey(_toChip), findsOneWidget);
    expect(find.byKey(_amChip), findsNothing);
    expect(find.byKey(_pmChip), findsNothing);
    expect(find.byKey(_dayChip), findsNothing);
  });

  testWidgets(
      'chips browse the canonical windows: a 14:00–15:00 reservation shows '
      'occupied for Afternoon and Day but free for Morning', (tester) async {
    final repo = FakeReservationRepository()
      ..reservations.add(reservationToday(startHour: 14, endHour: 15));
    await pumpHalfDayPlan(tester, reservations: repo);

    await tester.tap(find.byKey(_pmChip));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, _pmChip), isTrue);
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.occupied);

    await tester.tap(find.byKey(_amChip));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, _amChip), isTrue);
    expect(chipSelected(tester, _pmChip), isFalse);
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.free);

    await tester.tap(find.byKey(_dayChip));
    await tester.pumpAndSettle();
    expect(chipSelected(tester, _dayChip), isTrue);
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.occupied);
  });

  testWidgets(
      'a morning 09:00–10:00 reservation leaves the Afternoon window free',
      (tester) async {
    final repo = FakeReservationRepository()
      ..reservations.add(reservationToday(startHour: 9, endHour: 10));
    await pumpHalfDayPlan(tester, reservations: repo);

    await tester.tap(find.byKey(_pmChip));
    await tester.pumpAndSettle();
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.free);

    await tester.tap(find.byKey(_amChip));
    await tester.pumpAndSettle();
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.occupied);
  });

  testWidgets(
      'booking a free seat in Morning creates exactly 00:00–13:00 local, '
      'with no Until tile in the sheet', (tester) async {
    final repo = await pumpHalfDayPlan(tester);

    await tester.tap(find.byKey(_amChip));
    await tester.pumpAndSettle();
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts at 00:00'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Until'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    expect(created.status, ReservationStatus.reserved);
    final expected = HalfDayWindows.morning(DateTime.now());
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
  });

  testWidgets(
      'live walk-up checks in until the current half-day boundary, '
      'end not adjustable', (tester) async {
    final repo = await pumpHalfDayPlan(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts now'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Until'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    expect(created.status, ReservationStatus.checkedIn);
    // Before 13:00 the walk-up ends at 13:00, after at next-day 00:00 —
    // derived from the created start so the assertion is deterministic
    // whenever the suite runs.
    expect(
      created.endsAt.toUtc(),
      HalfDayWindows.windowForNow(created.startsAt).end.toUtc(),
    );
  });

  testWidgets(
      'the date button re-derives the selected half on the picked day',
      (tester) async {
    final repo = await pumpHalfDayPlan(tester);

    await tester.tap(find.byKey(_pmChip));
    await tester.pumpAndSettle();

    // Pick a mid-month day of the visible month (never today, so the
    // window provably moved; never ambiguous with the header text).
    final now = DateTime.now();
    final targetDay = now.day == 15 ? 16 : 15;
    await tester.tap(find.byKey(const ValueKey('plan-date-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$targetDay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Still the afternoon half — now on the picked day.
    expect(chipSelected(tester, _pmChip), isTrue);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts at 13:00'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = repo.reservations.single;
    final expected =
        HalfDayWindows.afternoon(DateTime(now.year, now.month, targetDay));
    expect(created.startsAt.toUtc(), expected.start.toUtc());
    expect(created.endsAt.toUtc(), expected.end.toUtc());
  });

  testWidgets(
      "a server half-day refusal maps to the dedicated message, not "
      "'seat may have just been taken'", (tester) async {
    await pumpHalfDayPlan(
      tester,
      reservations: ThrowingReservationRepository(
        const PostgrestException(
          message: 'bookings must cover a half-day '
              '(00:00-13:00, 13:00-24:00) or the full day',
        ),
      ),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(find.text('Bookings here are per half day.'), findsOneWidget);
    expect(
      find.text('Could not check in — the seat may have just been taken.'),
      findsNothing,
    );
  });
}
