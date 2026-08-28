// SPDX-License-Identifier: 0BSD
//
// Admin overrule (#412, cancel_reservation v2): "no multiple
// reservations — the owner and admin only can overrule an existing
// reservation; the other is removed and the user and all admins/owners
// are notified" (the 0007 cancel event is the notification channel).
// The plan sheet on another member's seat offers Remove to admins —
// any time, window open or not — while plain members keep the snackbar.

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'book_for_others_test.dart' show pumpPlanWithRoster;
import 'plan_screen_test.dart' show foreignReservation, seatCenter;
import 'time_scroller_test.dart' show pickChipTime;

void main() {
  // #490 — the fixture workspace is Europe/Berlin; anchor the SEEDS to
  // it too, so the suite passes on any device timezone.
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);
  testWidgets('owner removes a present member\'s reservation: cancelled '
      'and the snack says who was notified', (tester) async {
    final env = await pumpPlanWithRoster(
      tester,
      seedReservations: (repo) => repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // Window is open, so both admin tiles show.
    expect(find.text('Check in Ana Lima'), findsOneWidget);
    await tester.tap(find.text('Remove reservation (overrule)'));
    await tester.pumpAndSettle();

    expect(env.reservations.reservations.single.status,
        ReservationStatus.cancelled);
    expect(
      find.text('Reservation removed — Ana Lima was notified.'),
      findsOneWidget,
    );
  });

  testWidgets('browsing a FUTURE foreign reservation: the owner can '
      'overrule but not check in', (tester) async {
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
        reason: 'presence rule: nobody is standing there yet');
    await tester.tap(find.text('Remove reservation (overrule)'));
    await tester.pumpAndSettle();

    expect(env.reservations.reservations.single.status,
        ReservationStatus.cancelled);
  });

  testWidgets('a plain member gets no overrule tile', (tester) async {
    final env = await pumpPlanWithRoster(
      tester,
      viewerIsOwner: false,
      seedReservations: (repo) => repo.reservations.add(foreignReservation()),
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Remove reservation (overrule)'), findsNothing);
    expect(env.reservations.reservations.single.status,
        ReservationStatus.reserved);
  });
}
