// SPDX-License-Identifier: 0BSD
//
// Floor-plan semantics (#402, wiki 26): without a semanticsBuilder the
// app's core surface is one unlabeled picture to TalkBack/VoiceOver.
// Every seat must announce name · state (· occupant), and the semantic
// tap must open the same sheet a touch does — spec §11 finally has an
// enforcing test instead of a promise.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<void> _pumpPlan(
  WidgetTester tester, {
  List<Reservation> seed = const [],
}) async {
  final reservations = FakeReservationRepository()..reservations.addAll(seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        reservations: reservations,
        workspace: FakeWorkspaceRepository.withWorkspace()
          ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
          // Open every weekday (#186): seat-state tests must not hit
          // closed-day gating when the suite runs on a weekend.
          ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7],
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await switchToPlanTab(tester);
}

void main() {
  testWidgets('a free seat exposes a labeled, tappable semantics node, '
      'and the semantic tap opens the same booking sheet a touch does',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPlan(tester);

    // Painter semantics are tree nodes, not widget-backed — the widget
    // finder cannot see them; the semantics finder can.
    final freeSeat = find.semantics.byLabel('A1 · free');
    expect(freeSeat, findsOne,
        reason: 'seat A1 must announce its state, not be part of one '
            'unlabeled canvas');

    // Dispatch the ACCESSIBILITY tap — what TalkBack's double-tap
    // sends — not a pointer event at coordinates.
    tester.semantics.tap(freeSeat);
    await tester.pumpAndSettle();
    // The walk-up sheet's "Starts now" line proves the SAME sheet a
    // touch opens (the plan_screen_test contract).
    expect(find.textContaining('Starts now'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('an occupied seat announces its occupant after the state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPlan(tester, seed: [
      Reservation(
        id: 'res-foreign',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-2',
        startsAt: kTestNow.subtract(const Duration(hours: 1)),
        endsAt: kTestNow.add(const Duration(hours: 2)),
        status: ReservationStatus.checkedIn,
        checkedInAt: kTestNow.subtract(const Duration(hours: 1)),
      ),
    ]);

    // The occupant reads as the plan SHOWS it — the first name the
    // avatar label uses — so ears and eyes get the same information.
    expect(
      find.semantics.byLabel('A1 · occupied · Ana'),
      findsOne,
      reason: 'who holds the seat is information sighted users get from '
          'the avatar — the announcement must carry it too',
    );
    handle.dispose();
  });
}
