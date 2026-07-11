// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

const _cellSize = 14.0;

/// Pumps the app on the Plan tab with a seeded small plan
/// (office 30×20, desk at (2,2) 12×4, one seat 'A1' anchored at (2,2)).
Future<
    ({
      FakeFloorPlanRepository plans,
      FakeReservationRepository reservations,
      FakeWorkspaceRepository workspace,
    })> pumpPlan(
  WidgetTester tester, {
  void Function(FakeReservationRepository repo)? seedReservations,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    // Open every weekday: booking tests must not hit the closed-day
    // gating (#186) when the suite runs on a weekend.
    ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
  seedReservations?.call(reservations);
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
  return (plans: plans, reservations: reservations, workspace: workspace);
}

Offset seatCenter(WidgetTester tester) {
  final canvas =
      tester.getTopLeft(find.byKey(const ValueKey('live-plan-canvas')));
  // Seat footprint (2,2)..(8,6) → center cell ~(5,4).
  return canvas + const Offset(5 * _cellSize, 4 * _cellSize);
}

Reservation foreignReservation({
  ReservationStatus status = ReservationStatus.reserved,
}) {
  final now = DateTime.now();
  return Reservation(
    id: 'res-foreign',
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-2',
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: now.add(const Duration(hours: 2)),
    status: status,
  );
}

void main() {
  testWidgets('tapping a free seat walks up: sheet → atomic check-in',
      (tester) async {
    final env = await pumpPlan(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts now'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.status, ReservationStatus.checkedIn);
    expect(created.seatId, 'seat-4');
    expect(created.checkedInAt, isNotNull);
  });

  testWidgets('walk-up end is capped by the next reservation',
      (tester) async {
    final now = DateTime.now();
    final env = await pumpPlan(
      tester,
      seedReservations: (repo) {
        repo.reservations.add(
          Reservation(
            id: 'res-next',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-2',
            startsAt: now.add(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 3)),
            status: ReservationStatus.reserved,
          ),
        );
      },
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('The seat is reserved from'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    final mine = env.reservations.reservations
        .firstWhere((r) => r.memberId == 'member-1');
    expect(mine.endsAt.isAfter(now.add(const Duration(hours: 1))), isFalse);
  });

  testWidgets('tapping my checked-in seat offers check-out', (tester) async {
    final now = DateTime.now();
    final env = await pumpPlan(
      tester,
      seedReservations: (repo) {
        repo.reservations.add(
          Reservation(
            id: 'res-mine',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-1',
            startsAt: now.subtract(const Duration(hours: 1)),
            endsAt: now.add(const Duration(hours: 3)),
            status: ReservationStatus.checkedIn,
          ),
        );
      },
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check out'));
    await tester.pumpAndSettle();

    final mine = env.reservations.reservations.single;
    expect(mine.status, ReservationStatus.completed);
    expect(mine.checkedOutAt, isNotNull);
  });

  testWidgets("tapping someone else's seat explains who has it",
      (tester) async {
    await pumpPlan(
      tester,
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reserved by Ana'), findsOneWidget);
  });

  testWidgets('a blocked seat explains itself', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.single;
    plans.seats[0] = seat.copyWith(
      blockedFrom: DateTime.now().subtract(const Duration(days: 1)),
    );
    // Open every weekday: this test is about seat blocking, and on a
    // weekend run the closed-day gate (#186) would otherwise fire first.
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
    await tester.pumpWidget(
      ProviderScope(
        overrides:
            standardTestOverrides(floorPlan: plans, workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(
      find.text('This seat is blocked for maintenance.'),
      findsOneWidget,
    );
  });

  testWidgets('worker without levels sees the empty message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The workspace has no floor plan yet.'),
      findsOneWidget,
    );
  });
}
