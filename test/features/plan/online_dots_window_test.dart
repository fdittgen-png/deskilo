// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2486 -- the green dot on a taken seat follows the workspace's presence
// window (`presence.online_window_minutes`), not a constant: a heartbeat 8
// minutes old is offline at the default 5 and online at 10.
import 'package:deskilo/core/presence/presence_rules.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/presentation/seat_occupancy.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 6, 9);
  final from = DateTime.utc(2026, 8, 6, 8);
  final to = DateTime.utc(2026, 8, 6, 12);
  const plan = FloorPlan(
    levelId: 'level-1',
    offices: [
      Office(
        id: 'office-1',
        workspaceId: 'ws-1',
        levelId: 'level-1',
        name: 'Room',
        color: 0,
        bookableAsWhole: false,
        rect: GridRect(x: 0, y: 0, w: 10, h: 6),
      ),
    ],
    desks: [
      Desk(
        id: 'desk-1',
        workspaceId: 'ws-1',
        officeId: 'office-1',
        name: '',
        rect: GridRect(x: 1, y: 1, w: 6, h: 4),
      ),
    ],
    seats: [
      Seat(
        id: 'seat-1',
        workspaceId: 'ws-1',
        deskId: 'desk-1',
        name: 'A1',
        x: 1,
        y: 1,
        orientation: SeatOrientation.n,
        chair: '',
        amenities: [],
      ),
    ],
  );
  final reservation = Reservation(
    id: 'res-1',
    workspaceId: 'ws-1',
    seatId: 'seat-1',
    memberId: 'member-2',
    startsAt: from,
    endsAt: to,
    status: ReservationStatus.reserved,
  );
  const member = Member(
    id: 'member-2',
    workspaceId: 'ws-1',
    userId: 'user-2',
    isAdmin: false,
    isOwner: false,
    status: MemberStatus.active,
  );
  final profile = Profile(
    id: 'user-2',
    lastSeenAt: now.subtract(const Duration(minutes: 8)),
  );

  Set<String> dots({Duration? window}) => onlineSeatIdsFor(
    plan: plan,
    reservations: [reservation],
    members: const [member],
    profiles: {'user-2': profile},
    window: (from: from, to: to, now: now),
    onlineWindow: window ?? PresenceRules.onlineWindow,
  );

  test('a heartbeat 8 minutes old is offline at the default 5 minutes', () {
    expect(PresenceRules.onlineWindow, const Duration(minutes: 5));
    expect(dots(), isEmpty);
  });

  test('and online once the workspace widens the window to 10 minutes', () {
    expect(dots(window: const Duration(minutes: 10)), {'seat-1'});
  });

  test(
    'tightened to 3 minutes a 2-minute heartbeat still counts, 4 does not',
    () {
      final fresh = Profile(
        id: 'user-2',
        lastSeenAt: now.subtract(const Duration(minutes: 2)),
      );
      Set<String> with_(Profile p) => onlineSeatIdsFor(
        plan: plan,
        reservations: [reservation],
        members: const [member],
        profiles: {'user-2': p},
        window: (from: from, to: to, now: now),
        onlineWindow: const Duration(minutes: 3),
      );
      expect(with_(fresh), {'seat-1'});
      expect(
        with_(
          Profile(
            id: 'user-2',
            lastSeenAt: now.subtract(const Duration(minutes: 4)),
          ),
        ),
        isEmpty,
      );
    },
  );
}
