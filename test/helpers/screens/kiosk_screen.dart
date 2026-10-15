// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in kiosk_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_realtime_sync.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';

/// The suite clock. Suites that install the fixture workspace's tz
/// (setUpAll below) re-anchor it to 10:00 IN THAT FRAME; importers that
/// don't install a zone keep the naive default — both self-consistent.
FixedClock kioskClock = FixedClock(kTestNow);

/// Pumps the app signed in as the wall tablet's KIOSK account. Kiosk
/// mode never auto-loads (field request): the gate asks first — by
/// default this helper confirms it; [startKiosk] false stops at the gate.
Future<FakeReservationRepository> pumpKiosk(
  WidgetTester tester, {
  FakeNfcUidReader? nfc,
  FakeQrScanner? qrScan,
  Map<String, dynamic> featureFlags = const {},
  BookingGranularity? granularity,
  bool bookableLevel = false,
  bool startKiosk = true,
  FakeRealtimeSync? realtime,
  List<int>? openWeekdays,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (bookableLevel) {
    plans.levels[0] = plans.levels[0].copyWith(
      bookableAsWhole: true,
      priceCents: 1000,
    );
  }
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: featureFlags,
  );
  if (granularity != null) {
    workspace.bookingGranularities['ws-1'] = granularity;
  }
  if (openWeekdays != null) {
    workspace.openWeekdays['ws-1'] = openWeekdays;
  }
  workspace.myMember = workspace.myMember.copyWith(
    isAdmin: false,
    isOwner: false,
    isKiosk: true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
        nfc: nfc,
        qrScan: qrScan,
        realtime: realtime,
        clock: kioskClock,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (startKiosk) {
    await tester.tap(find.byKey(const ValueKey('kiosk-gate-start')));
    await tester.pumpAndSettle();
  }
  return reservations;
}

/// Centre of seat 'A1' on the kiosk canvas (footprint (2,2)..(8,6)).
Offset seatCenter(WidgetTester tester) {
  final canvas = tester.getTopLeft(find.byKey(_canvasKey));
  return canvas +
      const Offset(
        5 * PlanCanvasMetrics.cellSize,
        4 * PlanCanvasMetrics.cellSize,
      );
}

const _canvasKey = ValueKey('kiosk-plan-canvas');
