// SPDX-License-Identifier: MIT
//
// Kiosk mode (0043, K2): the router locks a kiosk account to the kiosk
// plan view; seat taps offer check-in / reserve / check-out, each
// completed by a badge code (wedge scanners type it) sent to the
// stateless kiosk_act RPC — nothing is retained on the device.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_screen.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

const _canvasKey = ValueKey('kiosk-plan-canvas');

/// Pumps the app signed in as the wall tablet's KIOSK account.
Future<FakeReservationRepository> pumpKiosk(
  WidgetTester tester, {
  FakeNfcUidReader? nfc,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace();
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
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
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

void main() {
  testWidgets(
      'a kiosk account is locked to the kiosk view: no shell, no bottom '
      'bar — just the plan', (tester) async {
    await pumpKiosk(tester);

    expect(find.byType(KioskScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-title')), findsOneWidget);
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('a regular member can never land on /kiosk', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(floorPlan: plans),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(KioskScreen), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets(
      'seat tap → Check in → badge code: kiosk_act runs with the token and '
      'the success flash shows (nothing retained)', (tester) async {
    final reservations = await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The action sheet names the seat and offers the three operations.
    expect(find.text('A1'), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-reserve')), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-check-out')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();

    // Badge prompt: a wedge scanner types the code and submits with Enter.
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final act = reservations.kioskActs.single;
    expect(act.action, 'check_in');
    expect(act.badgeToken, 'badge-token-1');
    expect(act.seatId, isNotNull);
    expect(find.textContaining("all set"), findsOneWidget);
  });

  testWidgets('a kiosk RFID tap sends the card UID straight to kiosk_act '
      '(0046)', (tester) async {
    final nfc = FakeNfcUidReader(available: true);
    final reservations = await pumpKiosk(tester, nfc: nfc);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();

    // NFC available → the prompt shows the tap hint; a card tap acts as
    // the credential without any typing.
    expect(find.textContaining('Tap your card'), findsOneWidget);
    nfc.tap('04a2b3c4d5');
    await tester.pumpAndSettle();

    final act = reservations.kioskActs.single;
    expect(act.action, 'check_in');
    expect(act.badgeToken, '04a2b3c4d5');
    expect(find.textContaining("all set"), findsOneWidget);
  });

  testWidgets('an unknown badge is refused with the badge error, not the '
      'generic one', (tester) async {
    final reservations = await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-out')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'bad-badge',
    );
    await tester.tap(find.byKey(const ValueKey('kiosk-badge-submit')));
    await tester.pumpAndSettle();

    expect(reservations.kioskActs, isEmpty);
    expect(find.text('Badge not recognized.'), findsOneWidget);
  });
}
