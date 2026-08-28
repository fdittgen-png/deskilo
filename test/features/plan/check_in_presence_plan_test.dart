// SPDX-License-Identifier: 0BSD
//
// Presence rule on the plan (#408): check-in means "I am standing here
// NOW". Browsing a future window must not offer a live check-in on my
// own reservation, and an admin may check in the member who is
// physically at the seat — gated like booking for others, inside the
// window only.

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'book_for_others_test.dart' show pumpPlanWithRoster;
import 'plan_screen_test.dart' show foreignReservation, pumpPlan, seatCenter;
import 'time_scroller_test.dart' show pickChipTime;

void main() {
  // #490 — the fixture workspace is Europe/Berlin; anchor the SEEDS to
  // it too, so the suite passes on any device timezone.
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);
  testWidgets(
      'browsing my future reservation: the check-in tile is disabled '
      'and says when the window opens', (tester) async {
    final now = kTestNow; // 10:00 — 23:00 is safely in the future
    final env = await pumpPlan(
      tester,
      seedReservations: (repo) {
        repo.reservations.add(
          Reservation(
            id: 'res-mine-future',
            workspaceId: 'ws-1',
            seatId: 'seat-4',
            memberId: 'member-1',
            startsAt: WorkspaceTime.at(now.year, now.month, now.day, 23),
            endsAt: WorkspaceTime.at(now.year, now.month, now.day, 23, 45),
            status: ReservationStatus.reserved,
          ),
        );
      },
    );

    await pickChipTime(tester, 'reserve-from-chip', hour: '23', minute: '00');
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Check in'),
    );
    expect(tile.enabled, isFalse,
        reason: 'the future cannot be attended from here and now');
    expect(find.text('Check-in opens at 22:45'), findsOneWidget);

    // Belt and braces: tapping the disabled tile changes nothing.
    await tester.tap(find.widgetWithText(ListTile, 'Check in'),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(env.reservations.reservations.single.status,
        ReservationStatus.reserved);
  });

  testWidgets(
      'live mode, my running reservation: check-in still offered and works',
      (tester) async {
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
            status: ReservationStatus.reserved,
          ),
        );
      },
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Check in'));
    await tester.pumpAndSettle();

    expect(env.reservations.reservations.single.status,
        ReservationStatus.checkedIn);
  });

  testWidgets(
      'an owner taps the reserved seat of a present member: '
      '"Check in {name}" checks them in directly (#408)', (tester) async {
    final env = await pumpPlanWithRoster(
      tester,
      seedReservations: (repo) => repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check in Ana Lima'));
    await tester.pumpAndSettle();

    final r = env.reservations.reservations.single;
    expect(r.status, ReservationStatus.checkedIn);
    expect(r.memberId, 'member-2',
        reason: 'the reservation stays the member\'s own — the admin '
            'only attested their presence');
  });

  testWidgets(
      'a plain member tapping the same seat gets the occupant snackbar, '
      'no check-in offer', (tester) async {
    final env = await pumpPlanWithRoster(
      tester,
      viewerIsOwner: false,
      seedReservations: (repo) => repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Check in Ana Lima'), findsNothing);
    expect(find.textContaining('Reserved by Ana Lima'), findsOneWidget);
    expect(env.reservations.reservations.single.status,
        ReservationStatus.reserved);
  });

  testWidgets(
      'the admin offer vanishes outside the window: a future foreign '
      'reservation browsed by an owner stays a snackbar', (tester) async {
    final now = kTestNow;
    final env = await pumpPlanWithRoster(
      tester,
      seedReservations: (repo) => repo.reservations.add(
        Reservation(
          id: 'res-foreign-future',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: WorkspaceTime.at(now.year, now.month, now.day, 23),
          endsAt: WorkspaceTime.at(now.year, now.month, now.day, 23, 45),
          status: ReservationStatus.reserved,
        ),
      ),
    );

    await pickChipTime(tester, 'reserve-from-chip', hour: '23', minute: '00');
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Check in Ana Lima'), findsNothing,
        reason: 'browse mode + window not open: nobody is present yet');
    expect(env.reservations.reservations.single.status,
        ReservationStatus.reserved);
  });
}
