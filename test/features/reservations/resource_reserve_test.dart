// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 checkpoint 5 — the reserve screen speaks the resource's own slot: a
// room is booked by the hour beside seats booked by the half day, a parking
// slot by the day, and the list names rooms and the electric slots.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/presentation/screens/reserve_window_rules.dart';
import 'package:deskilo/features/reservations/presentation/widgets/seat_list_view.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

DateTime _at(int h, [int m = 0]) => WorkspaceTime.at(2026, 5, 13, h, m);

final HalfDayWindow _day = (start: _at(8), end: _at(18));

void main() {
  group('ReserveWindowRules.resourceWindow', () {
    const halfDay = ReserveWindowRules(BookingGranularity.halfDay);
    final morning = HalfDayWindows.morning(_at(0));

    test('a seat without its own slot keeps the window asked for', () {
      expect(
        halfDay.resourceWindow(null, asked: morning, now: _at(7), day: _day),
        morning,
      );
    });

    test('a room (60 minutes) in a half-day workspace opens at the opening '
        'hour, for one hour', () {
      final w = halfDay.resourceWindow(
        60,
        asked: morning,
        now: _at(7),
        day: _day,
      );
      expect(w, (start: _at(8), end: _at(9)));
    });

    test('today, the room starts at the next free hour, not in the past', () {
      final w = halfDay.resourceWindow(
        60,
        asked: morning,
        now: _at(10, 20),
        day: _day,
      );
      expect(w.start, _at(11));
      expect(w.end, _at(12));
    });

    test('the hour that was tapped is the hour that is booked', () {
      final w = halfDay.resourceWindow(
        60,
        asked: (start: _at(14, 25), end: _at(14, 26)),
        now: _at(7),
        day: _day,
      );
      expect(w, (start: _at(14), end: _at(15)));
    });

    test('a parking slot (1440) is booked for the whole day', () {
      final w = halfDay.resourceWindow(
        1440,
        asked: morning,
        now: _at(7),
        day: _day,
      );
      expect(w, HalfDayWindows.fullDay(_at(0)));
    });

    test('a 30-minute room in a flexible workspace snaps to its grid and '
        'lasts a slot', () {
      const flexible = ReserveWindowRules(BookingGranularity.flexible);
      final w = flexible.resourceWindow(
        30,
        asked: (start: _at(10, 10), end: _at(10, 40)),
        now: _at(7),
        day: _day,
      );
      expect(w, (start: _at(10), end: _at(11)));
    });

    test('a walk-up on a resource ends with its slot', () {
      final slot = (start: _at(11), end: _at(12));
      expect(halfDay.walkUpEnd(slot, period: null, ownSlot: true), _at(12));
    });
  });

  testWidgets('the list names a room, its capacity and slot, and marks the '
      'electric parking slot', (tester) async {
    const rect = GridRect(x: 0, y: 0, w: 20, h: 20);
    const plan = FloorPlan(
      levelId: 'l1',
      offices: [
        Office(
          id: 'o1',
          workspaceId: 'ws-1',
          levelId: 'l1',
          name: 'Floor',
          color: 0,
          bookableAsWhole: false,
          rect: rect,
        ),
      ],
      desks: [
        Desk(
          id: 'd1',
          workspaceId: 'ws-1',
          officeId: 'o1',
          name: 'Desk',
          rect: rect,
        ),
      ],
      seats: [
        Seat(
          id: 'room',
          workspaceId: 'ws-1',
          deskId: 'd1',
          name: 'Boardroom',
          x: 0,
          y: 0,
          orientation: SeatOrientation.n,
          chair: '',
          amenities: [],
          resourceKind: ResourceKind.room,
          capacity: 8,
          slotMinutes: 60,
        ),
        Seat(
          id: 'ev',
          workspaceId: 'ws-1',
          deskId: 'd1',
          name: 'P1',
          x: 7,
          y: 0,
          orientation: SeatOrientation.n,
          chair: '',
          amenities: [],
          resourceKind: ResourceKind.parking,
          parkingKind: ParkingKind.ev,
          slotMinutes: 1440,
        ),
        Seat(
          id: 'plain',
          workspaceId: 'ws-1',
          deskId: 'd1',
          name: 'A1',
          x: 0,
          y: 5,
          orientation: SeatOrientation.n,
          chair: '',
          amenities: [],
        ),
      ],
    );
    final floorPlan = FakeFloorPlanRepository()
      ..levels.add(
        const Level(
          id: 'l1',
          workspaceId: 'ws-1',
          name: 'Ground',
          sortOrder: 0,
        ),
      );
    await pumpApp(
      tester,
      Scaffold(
        body: SeatListView(
          plan: plan,
          reservations: const [],
          names: const {},
          at: DateTime.utc(2026, 5, 13, 9),
          windowEndOrNull: DateTime.utc(2026, 5, 13, 13),
          dayOpen: true,
          onSeatTap: (_) {},
        ),
      ),
      overrides: standardTestOverrides(floorPlan: floorPlan),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Meeting room · 8 people · Booked by the hour'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Parking slot · electric (charger included) · Booked by the day',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.ev_station_outlined), findsOneWidget);
    expect(find.byIcon(Icons.meeting_room_outlined), findsNWidgets(2),
        reason: 'the office header and the room');
    expect(
      find.byIcon(Icons.event_seat_outlined),
      findsOneWidget,
      reason: 'the plain seat keeps its icon',
    );
  });
}
