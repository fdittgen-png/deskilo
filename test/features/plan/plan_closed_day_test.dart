// SPDX-License-Identifier: MIT
//
// #186: on days the workspace is closed (weekday not open / closure day)
// the plan must say so — banner, muted seats, gated taps — and booking
// refusals from `assert_workspace_open` must map to a clear message
// instead of "the seat may have just been taken".
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import 'plan_screen_test.dart' show seatCenter;

const _bannerKey = ValueKey('plan-closed-banner');
const _closedDayText = 'Closed on this day';
const _closedDayErrorText = 'The workspace is closed on that day.';

/// The server refusal of `assert_workspace_open` (migration 0013),
/// weekday variant; the closure-day variant shares the matched prefix.
const _serverClosedMessage =
    'workspace is closed on 2026-07-11 (weekday not open)';

/// Every ISO weekday except today's — makes the live "now" day closed.
List<int> allWeekdaysExceptToday() {
  final today = DateTime.now().weekday;
  return [
    for (var day = 1; day <= 7; day++)
      if (day != today) day,
  ];
}

/// Pumps the Plan tab with the seeded small plan and controllable
/// availability (#186). Defaults to open every weekday, no closures.
Future<FakeReservationRepository> pumpAvailabilityPlan(
  WidgetTester tester, {
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  List<ClosureDay> closures = const [],
  FakeReservationRepository? reservations,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservationRepo = reservations ?? FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    ..openWeekdays['ws-1'] = openWeekdays
    ..closureDays.addAll(closures);
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
  return reservationRepo;
}

/// The painter of the live plan canvas.
FloorPlanPainter planPainter(WidgetTester tester) {
  final paint = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('live-plan-canvas')));
  return paint.painter! as FloorPlanPainter;
}

/// [FakeReservationRepository] whose booking/check-in writers throw
/// [error] — the closed-day RPC refusal path (fakes over mocks).
class ThrowingReservationRepository extends FakeReservationRepository {
  ThrowingReservationRepository(this.error);

  final Object error;

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? officeId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    throw error;
  }

  @override
  Future<void> checkIn(String reservationId) async {
    throw error;
  }
}

void main() {
  testWidgets(
      'closed weekday: banner shown, every seat muted, tap shows the closed '
      'message instead of a booking sheet', (tester) async {
    await pumpAvailabilityPlan(
      tester,
      openWeekdays: allWeekdaysExceptToday(),
    );

    expect(find.byKey(_bannerKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_bannerKey),
        matching: find.text(_closedDayText),
      ),
      findsOneWidget,
    );
    // Muted: the canvas renders every seat in the blocked state.
    final states = planPainter(tester).seatStates!;
    expect(states, isNotEmpty);
    expect(states.values, everyElement(SeatState.blocked));

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts now'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(_closedDayText),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a closure day closes an otherwise open weekday',
      (tester) async {
    final today = DateTime.now();
    await pumpAvailabilityPlan(
      tester,
      closures: [
        ClosureDay(
          id: 'closure-1',
          workspaceId: 'ws-1',
          day: DateTime(today.year, today.month, today.day),
          reason: 'Holiday',
        ),
      ],
    );

    expect(find.byKey(_bannerKey), findsOneWidget);
  });

  testWidgets('open day: no banner, seat tap opens the booking sheet',
      (tester) async {
    await pumpAvailabilityPlan(tester);

    expect(find.byKey(_bannerKey), findsNothing);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts now'), findsOneWidget);
  });

  testWidgets(
      'list view on a closed day: rows muted with the closed text, tap '
      'shows the closed message instead of a sheet', (tester) async {
    await pumpAvailabilityPlan(
      tester,
      openWeekdays: allWeekdaysExceptToday(),
    );

    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    final row = find.widgetWithText(ListTile, 'A1');
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.textContaining(_closedDayText)),
      findsOneWidget,
    );

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts now'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(_closedDayText),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'a closed-day refusal from the walk-up booking RPC maps to the '
      'closed-day message, not "seat may have just been taken"',
      (tester) async {
    await pumpAvailabilityPlan(
      tester,
      reservations: ThrowingReservationRepository(
        const PostgrestException(message: _serverClosedMessage),
      ),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(find.text(_closedDayErrorText), findsOneWidget);
    expect(
      find.text('Could not check in — the seat may have just been taken.'),
      findsNothing,
    );
  });

  testWidgets('other booking failures keep the generic taken message',
      (tester) async {
    await pumpAvailabilityPlan(
      tester,
      reservations: ThrowingReservationRepository(
        const PostgrestException(message: 'conflicting reservation exists'),
      ),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not check in — the seat may have just been taken.'),
      findsOneWidget,
    );
    expect(find.text(_closedDayErrorText), findsNothing);
  });

  testWidgets(
      'a closed-day refusal from the check-in RPC on my reservation maps '
      'to the closed-day message', (tester) async {
    final now = DateTime.now();
    final reservations = ThrowingReservationRepository(
      const PostgrestException(message: _serverClosedMessage),
    )..reservations.add(
        Reservation(
          id: 'res-mine',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-1',
          startsAt: now.subtract(const Duration(minutes: 30)),
          endsAt: now.add(const Duration(hours: 2)),
          status: ReservationStatus.reserved,
        ),
      );
    await pumpAvailabilityPlan(tester, reservations: reservations);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Check in'));
    await tester.pumpAndSettle();

    expect(find.text(_closedDayErrorText), findsOneWidget);
  });
}
