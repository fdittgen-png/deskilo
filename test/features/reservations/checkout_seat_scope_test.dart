// SPDX-License-Identifier: 0BSD
//
// #1083 — the scan sheet's Check-out branch filtered the day's
// reservations by member, status and end time, but NOT by seat, then
// took `firstOrNull` of an unordered list. With
// `simultaneous_reservations > 1` a member checked into two seats who
// scans the second gets checked out of the FIRST, and the sheet says
// "Done". `_myCheckInTarget` in the same class applies the seat
// predicate correctly on the check-IN branch; the check-out branch
// dropped it.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('scanning the seat I am sitting at checks out THAT seat',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seatA = plans.seats.single;
    // A second seat on the same desk.
    final seatB = Seat(
      id: 'seat-b',
      workspaceId: 'ws-1',
      deskId: seatA.deskId,
      name: 'A2',
      x: 6,
      y: 2,
      orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: const [],
    );
    plans.seats.add(seatB);

    final reservations = FakeReservationRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];

    // I am checked in on BOTH seats. Seeded directly so both are live at
    // once — the fake's create path enforces one place per member.
    final me = reservations.myMemberId;
    reservations.reservations.addAll([
      Reservation(
        id: 'res-a',
        workspaceId: 'ws-1',
        seatId: seatA.id,
        memberId: me,
        startsAt: kTestNow.subtract(const Duration(hours: 1)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      ),
      Reservation(
        id: 'res-b',
        workspaceId: 'ws-1',
        seatId: seatB.id,
        memberId: me,
        startsAt: kTestNow.subtract(const Duration(minutes: 30)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(minutes: 30)),
      ),
    ]);

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
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-scan-field')),
      SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.seat,
        id: seatB.id,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('space-act-check-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-act-confirm')));
    await tester.pumpAndSettle();

    final a = reservations.reservations.firstWhere((r) => r.id == 'res-a');
    final b = reservations.reservations.firstWhere((r) => r.id == 'res-b');
    expect(b.status, isNot(ReservationStatus.checkedIn),
        reason: 'the SCANNED seat is the one released');
    expect(a.status, ReservationStatus.checkedIn,
        reason: 'the seat I did not scan must be left alone');
  });
}
