// SPDX-License-Identifier: 0BSD
//
// #1135 — a member already sitting at a seat, who opens that seat's
// sheet, was one tap from a request that could not succeed.
//
// From a field trace (2026-09-11, workspace 5ffea179):
//
//   11:37:44.494 INFO  scan-check-in seat=2f14… target=null route=walk-up
//   11:37:44.571 ERROR reserve failed … | PostgrestException(
//     message: you already have a reservation in that period
//              (at most 1 at a time), code: P0001)
//   … and four more, through 11:37:46.885.
//
// Five identical creates in two and a half seconds, every one of them
// impossible, on a seat the member was already checked into.
//
// The cause is one clause. `_myCheckInTarget` gates on
// `checkInWindowOpen`, which opens with
// `status != ReservationStatus.reserved → false`. A reservation the
// member is ALREADY CHECKED INTO is therefore invisible to it; it
// returns null; and `_confirm` reads that null as "nothing of mine here,
// walk up and create one". The server refuses — correctly — and the
// member is told something they cannot act on, so they tap again.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeReservationRepository> _openSheetOnMyOccupiedSeat(
  WidgetTester tester, {
  Duration liveFor = const Duration(hours: 3),
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final seat = plans.seats.single;
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];

  // Exactly the field state: my own reservation on this seat, live.
  reservations.reservations.add(
    Reservation(
      id: 'res-mine',
      workspaceId: 'ws-1',
      seatId: seat.id,
      memberId: reservations.myMemberId,
      startsAt: kTestNow.subtract(const Duration(hours: 1)),
      endsAt: kTestNow.add(liveFor),
      status: ReservationStatus.checkedIn,
      checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
    ),
  );

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
      id: seat.id,
    ),
  );
  await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
  await tester.pumpAndSettle();
  return reservations;
}

void main() {
  testWidgets('the sheet opens on Check out, not Check in', (tester) async {
    await _openSheetOnMyOccupiedSeat(tester);

    final checkOut = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('space-act-check-out')),
    );
    expect(checkOut.selected, isTrue,
        reason: 'already sitting here — the move left is to leave');
  });

  testWidgets('choosing Check in says why, and Confirm is refused',
      (tester) async {
    final reservations = await _openSheetOnMyOccupiedSeat(tester);

    await tester.tap(find.byKey(const ValueKey('space-act-check-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-act-own-standing')), findsOneWidget,
        reason: 'the reason belongs on screen BEFORE the tap — a greyed '
            'button is not an answer');
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('space-act-confirm')),
    );
    expect(confirm.onPressed, isNull);

    // And nothing was sent. This is the assertion that fails before the
    // fix: the create reaches the repository and the server refuses it.
    expect(reservations.createCalls, 0,
        reason: 'a request that cannot succeed must never leave the device');
  });

  testWidgets('a seat I merely RESERVED still offers a working check-in',
      (tester) async {
    // The guard must not swallow the ordinary case: reserved-not-yet-
    // checked-in is exactly what the check-in branch exists for.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.single;
    final reservations = FakeReservationRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    reservations.reservations.add(
      Reservation(
        id: 'res-reserved',
        workspaceId: 'ws-1',
        seatId: seat.id,
        memberId: reservations.myMemberId,
        startsAt: kTestNow.subtract(const Duration(minutes: 10)),
        endsAt: kTestNow.add(const Duration(hours: 3)),
        status: ReservationStatus.reserved,
      ),
    );

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
        id: seat.id,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-act-own-standing')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('space-act-confirm')));
    await tester.pumpAndSettle();

    final mine =
        reservations.reservations.firstWhere((r) => r.id == 'res-reserved');
    expect(mine.status, ReservationStatus.checkedIn,
        reason: 'it checks into the EXISTING reservation, never creates');
    expect(reservations.createCalls, 0);
  });

  testWidgets('the refusal is about OVERLAP, not about the seat',
      (tester) async {
    // Checked in until 11:30. Reserve opens on a window starting NOW,
    // which overlaps the live check-in — so the refusal must show. The
    // non-overlapping half is the pure test below: the sheet asks
    // exactly `coversRange`, and `enforce_one_place` counts overlaps and
    // nothing else, so the sheet must not be stricter than the server.
    await _openSheetOnMyOccupiedSeat(
      tester,
      liveFor: const Duration(minutes: 90),
    );
    await tester.tap(find.byKey(const ValueKey('space-act-reserve')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('space-act-own-standing')), findsOneWidget,
        reason: 'a window starting now overlaps my live check-in');
  });

  test('a later window on the same seat does not overlap the live check-in',
      () {
    final live = Reservation(
      id: 'res-mine',
      workspaceId: 'ws-1',
      seatId: 'seat-1',
      memberId: 'me',
      startsAt: kTestNow.subtract(const Duration(hours: 1)),
      endsAt: kTestNow.add(const Duration(minutes: 90)),
      status: ReservationStatus.checkedIn,
      checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
    );
    // The predicate the sheet's refusal is built on (#184 semantics:
    // end-exclusive), for the window a member would pick to come back
    // this afternoon.
    final afternoon = kTestNow.add(const Duration(hours: 3));
    expect(live.coversRange(afternoon, afternoon.add(const Duration(hours: 4))),
        isFalse, reason: 'the seat stays mine to book for later');
    expect(live.coversRange(kTestNow, kTestNow.add(const Duration(hours: 2))),
        isTrue, reason: 'and a window starting now is the impossible one');
  });
}
