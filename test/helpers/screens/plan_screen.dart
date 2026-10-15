// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in plan_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

/// Pumps the app on the Plan tab with a seeded small plan
/// (office 30×20, desk at (2,2) 12×4, one seat 'A1' anchored at (2,2)).
Future<
  ({
    FakeFloorPlanRepository plans,
    FakeReservationRepository reservations,
    FakeWorkspaceRepository workspace,
  })
>
pumpPlan(
  WidgetTester tester, {
  void Function(FakeReservationRepository repo)? seedReservations,
  // #622 — regular members see the message-the-reserver sheet where
  // admins get the admin actions; flags flow through as usual.
  bool regularMember = false,
  Map<String, dynamic> featureFlags = const {},
  Clock? clock,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository();
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
        // Open every weekday: booking tests must not hit the closed-day
        // gating (#186) when the suite runs on a weekend.
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
  if (regularMember) {
    workspace.myMember = workspace.myMember.copyWith(
      isAdmin: false,
      isOwner: false,
    );
  }
  seedReservations?.call(reservations);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
        clock: clock,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
  return (plans: plans, reservations: reservations, workspace: workspace);
}

Offset seatCenter(WidgetTester tester) {
  // Transform-aware (#278 idiom): the canvas auto-fits to the plan, and
  // the fit scale follows the viewport height (the compact header grew
  // the canvas). Content position = origin + content offset × rendered
  // scale (top-right minus top-left over the content width in px).
  final finder = find.byKey(const ValueKey('reserve-plan-canvas'));
  final topLeft = tester.getTopLeft(finder);
  final scale =
      (tester.getTopRight(finder).dx - topLeft.dx) /
      (PlanCanvasMetrics.cells * PlanCanvasMetrics.cellSize);
  // Seat footprint (2,2)..(8,6) → center cell ~(5,4).
  return topLeft + const Offset(5 * _cellSize, 4 * _cellSize) * scale;
}

/// #2016 — a free seat opens on Reserve; checking in now is the member's
/// explicit choice in the sheet.
Future<void> chooseCheckInNow(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('booking-mode-check-in')));
  await tester.pumpAndSettle();
}

Reservation foreignReservation({
  ReservationStatus status = ReservationStatus.reserved,
}) {
  final now = kTestNow;
  return Reservation(
    id: 'res-foreign',
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-2',
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: now.add(const Duration(hours: 2)),
    status: status,
  );
}

const _cellSize = 14.0;
