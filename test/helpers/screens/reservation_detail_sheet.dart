// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in reservation_detail_sheet_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_accessory_repository.dart';
import '../fake_event_repository.dart';
import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../in_memory_default_level_store.dart';
import '../mock_providers.dart';

/// A 2-hour reservation of member-1 starting at [start] — on the seeded
/// seat ('seat-4' = A1) or, when [officeId] is set instead, on the office.
Reservation reservationAt(DateTime start, {String? seatId, String? officeId}) {
  return Reservation(
    id: 'res-1',
    workspaceId: 'ws-1',
    seatId: seatId,
    officeId: officeId,
    memberId: 'member-1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
  );
}

/// Pumps the app with the small seeded plan (level-1 'Ground floor',
/// office-2 'Main room', desk-3 'Window desk', seat-4 'A1') and switches
/// to the Calendar tab.
Future<InMemoryDefaultLevelStore> pumpCalendarApp(
  WidgetTester tester, {
  required List<Reservation> seed,
  FakeAccessoryRepository? accessories,
  FakeEventRepository? events,
  bool twoLevels = false,
  String? storedLevelId,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (twoLevels) {
    plans.levels.add(
      const Level(
        id: 'level-upper',
        workspaceId: 'ws-1',
        name: 'First floor',
        sortOrder: 1,
      ),
    );
  }
  final store = InMemoryDefaultLevelStore();
  if (storedLevelId != null) store.values['ws-1'] = storedLevelId;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        // #718 — the CLASSIC calendar is under test here.
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'calendarHub': false},
        ),
        floorPlan: plans,
        reservations: FakeReservationRepository()..reservations.addAll(seed),
        accessories: accessories ?? FakeAccessoryRepository(),
        events: events,
        defaultLevel: store,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return store;
}
