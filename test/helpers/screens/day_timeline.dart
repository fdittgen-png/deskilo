// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in day_timeline_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';

/// A reservation today from [startHour] to [startHour]+2 on the seeded
/// seat ('seat-4' = A1) unless [seatId]/[officeId] say otherwise.
Reservation todayReservation({
  String id = 'res-1',
  String memberId = 'member-1',
  String? seatId = 'seat-4',
  String? officeId,
  int startHour = 9,
}) {
  final now = kTestNow;
  final start = WorkspaceTime.at(now.year, now.month, now.day, startHour);
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: seatId,
    officeId: officeId,
    memberId: memberId,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
  );
}

/// Adds a second level ('First floor') with office/desk and seat 'B1'
/// (id 'seat-9') to the seeded small plan.
void addSecondLevel(FakeFloorPlanRepository plans) {
  plans.levels.add(
    const Level(
      id: 'level-9',
      workspaceId: 'ws-1',
      name: 'First floor',
      sortOrder: 1,
    ),
  );
  plans.offices.add(
    const Office(
      id: 'office-9',
      workspaceId: 'ws-1',
      levelId: 'level-9',
      name: 'Quiet room',
      color: 1,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 30, h: 20),
    ),
  );
  plans.desks.add(
    const Desk(
      id: 'desk-9',
      workspaceId: 'ws-1',
      officeId: 'office-9',
      name: 'Corner desk',
      rect: GridRect(x: 2, y: 2, w: 12, h: 4),
    ),
  );
  plans.seats.add(
    const Seat(
      id: 'seat-9',
      workspaceId: 'ws-1',
      deskId: 'desk-9',
      name: 'B1',
      x: 2,
      y: 2,
      orientation: SeatOrientation.n,
      chair: 'standard',
      amenities: [],
    ),
  );
}

/// Pumps the app on the Calendar tab and switches the selected-day area
/// to the timeline view (#187). [mutatePlans] tweaks the seeded plan
/// repository before pumping (e.g. an extra seat-less level for #221).
Future<FakeReservationRepository> pumpTimeline(
  WidgetTester tester, {
  List<Reservation> seed = const [],
  bool twoLevels = false,
  void Function(FakeFloorPlanRepository plans)? mutatePlans,
}) async {
  // Portrait: the timeline behaviour tests run the non-split layout (the
  // 800×600 default is landscape and would engage the calendar side panel).
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) addSecondLevel(plans);
  mutatePlans?.call(plans);
  final reservations = FakeReservationRepository()..reservations.addAll(seed);
  final workspace = FakeWorkspaceRepository.withWorkspace(
    // #718 — these test the CLASSIC calendar; the hub has its own file.
    featureFlags: const {'calendarHub': false},
  )..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
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
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.view_timeline_outlined));
  await tester.pumpAndSettle();
  return reservations;
}
