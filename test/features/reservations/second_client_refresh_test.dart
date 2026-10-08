// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1974 — a booking made on ANOTHER device redraws this one's plan with
// no action here: the database change reaches the open Reserve hub and
// the seat turns from free to taken. And a booking committed while this
// device's channel was down still lands, through the resync the channel
// emits when it comes back (#577). The FakeRealtimeSync stands in for the
// Supabase channel, as in test/core/realtime_sync_test.dart.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/realtime_providers.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_realtime_sync.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

const _canvasKey = ValueKey('reserve-plan-canvas');

SeatState? _seat(WidgetTester tester) =>
    (tester.widget<CustomPaint>(find.byKey(_canvasKey)).painter!
            as FloorPlanPainter)
        .seatStates?['seat-4'];

Future<({FakeReservationRepository repo, FakeRealtimeSync realtime})> _open(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = FakeReservationRepository();
  final realtime = FakeRealtimeSync();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        reservations: repo,
        workspace: FakeWorkspaceRepository.withWorkspace()
          ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
          ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7],
        realtime: realtime,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ShellCenterButton));
  await tester.pumpAndSettle();
  return (repo: repo, realtime: realtime);
}

/// Ana's booking of the seat for the whole of today, made elsewhere.
Reservation _anaToday() => Reservation(
  id: 'res-elsewhere',
  workspaceId: 'ws-1',
  seatId: 'seat-4',
  memberId: 'member-2',
  startsAt: DateTime(kTestNow.year, kTestNow.month, kTestNow.day),
  endsAt: DateTime(kTestNow.year, kTestNow.month, kTestNow.day, 23, 59),
  status: ReservationStatus.reserved,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(kRealtimeDebounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('another device books the seat: the open plan shows it taken', (
    tester,
  ) async {
    final r = await _open(tester);
    expect(_seat(tester), SeatState.free);

    // Nobody touches this device; the database emits the change.
    r.repo.reservations.add(_anaToday());
    r.realtime.emit('reservations');
    await _settle(tester);

    expect(_seat(tester), SeatState.reserved);
  });

  testWidgets('a booking made while the channel was down lands on reconnect', (
    tester,
  ) async {
    final r = await _open(tester);
    expect(_seat(tester), SeatState.free);

    // No reservations event was ever delivered; the re-subscribe resyncs.
    r.repo.reservations.add(_anaToday());
    r.realtime.emit(kResyncSignal);
    await _settle(tester);

    expect(_seat(tester), SeatState.reserved);
  });
}
