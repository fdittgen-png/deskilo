// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tapping a seat: walk-up check-in capped by the next booking, check-out,
// and an explanation for a taken or blocked seat.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import '../../helpers/screens/plan_screen.dart' show chooseCheckInNow, foreignReservation, pumpPlan, seatCenter;






void main() {
  testWidgets('tapping a free seat and choosing Check in now walks up: sheet → atomic check-in',
      (tester) async {
    final env = await pumpPlan(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await chooseCheckInNow(tester);
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
    final now = kTestNow;
    // The plan looks for "the next reservation" within the live local
    // day — a seed at now+1h crosses midnight on late-evening runs (bit
    // CI at 23:14 UTC), so clamp it inside today like #191 clamped the
    // open weekdays.
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    var nextStart = now.add(const Duration(hours: 1));
    if (nextStart.isAfter(endOfDay)) nextStart = endOfDay;
    if (!nextStart.isAfter(now)) {
      nextStart = now.add(const Duration(seconds: 30));
    }
    final env = await pumpPlan(
      tester,
      seedReservations: (repo) {
        repo.reservations.add(
          Reservation(
            id: 'res-next',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-2',
            startsAt: nextStart,
            endsAt: nextStart.add(const Duration(hours: 2)),
            status: ReservationStatus.reserved,
          ),
        );
      },
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await chooseCheckInNow(tester);
    expect(find.textContaining('The seat is reserved from'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    final mine = env.reservations.reservations
        .firstWhere((r) => r.memberId == 'member-1');
    expect(mine.endsAt.isAfter(nextStart), isFalse);
  });

  testWidgets('tapping my checked-in seat offers check-out', (tester) async {
    final now = kTestNow;
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
      blockedFrom: kTestNow.subtract(const Duration(days: 1)),
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
    await switchToPlanTab(tester);

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

  testWidgets(
      'the plan viewer pans UNBOUNDED (field report): a finite boundary '
      'made InteractiveViewer clamp the centred auto-fit of a small '
      'level — snapping it to the left border and locking horizontal '
      'panning', (tester) async {
    await pumpPlan(tester);
    final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer).first);
    expect(viewer.boundaryMargin, const EdgeInsets.all(double.infinity));
  });
}
