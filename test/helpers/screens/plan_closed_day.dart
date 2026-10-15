// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in plan_closed_day_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

/// Pumps the Plan tab with the seeded small plan and controllable
/// availability (#186). Defaults to open every weekday, no closures.
Future<FakeReservationRepository> pumpAvailabilityPlan(
  WidgetTester tester, {
  List<int> openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  List<ClosureDay> closures = const [],
  FakeReservationRepository? reservations,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservationRepo = reservations ?? FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    ..openWeekdays['ws-1'] = openWeekdays
    ..closureDays.addAll(closures);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservationRepo,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
  return reservationRepo;
}

/// [FakeReservationRepository] whose booking/check-in writers throw
/// [error] — the closed-day RPC refusal path (fakes over mocks).
class ThrowingReservationRepository extends FakeReservationRepository {
  ThrowingReservationRepository(this.error);

  final Exception error;

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
    String? requestId,
  }) async {
    throw error;
  }

  @override
  Future<void> checkIn(String reservationId) async {
    throw error;
  }
}
