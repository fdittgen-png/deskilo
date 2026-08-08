// SPDX-License-Identifier: 0BSD
//
// Kiosk mode (0043, K2): the router locks a kiosk account to the kiosk
// plan view; seat taps offer check-in / reserve / check-out, each
// completed by a badge code (wedge scanners type it) sent to the
// stateless kiosk_act RPC — nothing is retained on the device.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/core/nfc/nfc_uid_reader.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_screen.dart';
import 'package:deskilo/features/plan/presentation/widgets/plan_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/fake_realtime_sync.dart';
import '../../helpers/mock_providers.dart';

const _canvasKey = ValueKey('kiosk-plan-canvas');

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
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (bookableLevel) {
    plans.levels[0] = plans.levels[0]
        .copyWith(bookableAsWhole: true, priceCents: 1000);
  }
  final reservations = FakeReservationRepository();
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags);
  if (granularity != null) {
    workspace.bookingGranularities['ws-1'] = granularity;
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

/// Confirms the summary dialog (identify → résumé → Confirm) the
/// confirm-step flow inserts between the badge read and kiosk_act.
Future<void> confirmSummary(WidgetTester tester) async {
  expect(
    find.byKey(const ValueKey('kiosk-summary-name')),
    findsOneWidget,
  );
  await tester.tap(find.byKey(const ValueKey('kiosk-summary-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  // #490 idiom — the fixture workspace is Europe/Berlin; anchor the
  // suite AND the clock to it, so half-day windows and "now" live in
  // the same frame on any device timezone.
  setUpAll(() {
    WorkspaceTime.install('Europe/Berlin');
    kioskClock = FixedClock(
        WorkspaceTime.at(kTestNow.year, kTestNow.month, kTestNow.day, 10));
  });
  tearDownAll(WorkspaceTime.reset);
  testWidgets(
      'the gate asks before kiosk mode loads; confirming locks the pad '
      'to the kiosk view: no shell, no bottom bar, back disabled',
      (tester) async {
    await pumpKiosk(tester, startKiosk: false);

    // Kiosk mode never auto-loads — the gate asks first.
    expect(find.byKey(const ValueKey('kiosk-gate-title')), findsOneWidget);
    expect(find.byType(KioskScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('kiosk-gate-start')));
    await tester.pumpAndSettle();

    expect(find.byType(KioskScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-title')), findsOneWidget);
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
    // Locked: the back button/gesture cannot leave kiosk mode.
    final scope = tester.widget<PopScope>(
      find.descendant(
        of: find.byType(KioskScreen),
        matching: find.bySubtype<PopScope>(),
      ),
    );
    expect(scope.canPop, isFalse);
  });

  testWidgets(
      'a kiosk profile reverts ITSELF from Settings (0056): reject the '
      'gate, Settings → Kiosk device → confirm — the membership flips '
      'and the tile disappears', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember = workspace.myMember.copyWith(
      isAdmin: false,
      isOwner: false,
      isKiosk: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
          workspace: workspace,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-gate-reject')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-kiosk-revert')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-revert-confirm')));
    await tester.pumpAndSettle();

    expect(workspace.myMember.isKiosk, isFalse);
    expect(
      find.byKey(const ValueKey('settings-kiosk-revert')),
      findsNothing,
    );
  });

  testWidgets(
      'rejecting the gate lets the app start normally — shell and bottom '
      'bar, no kiosk view until the next app start', (tester) async {
    await pumpKiosk(tester, startKiosk: false);

    await tester.tap(find.byKey(const ValueKey('kiosk-gate-reject')));
    await tester.pumpAndSettle();

    expect(find.byType(KioskScreen), findsNothing);
    expect(find.byKey(const ValueKey('kiosk-gate-title')), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
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
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();

    // Badge prompt: a wedge scanner types the code and submits with Enter.
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await confirmSummary(tester);

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
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();

    // NFC available → the prompt shows the tap hint; a card tap acts as
    // the credential without any typing.
    expect(find.textContaining('Tap your card'), findsOneWidget);
    nfc.tap('04a2b3c4d5');
    await tester.pumpAndSettle();
    await confirmSummary(tester);

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

  testWidgets(
      'whole-level flow (0050): the level button offers the actions, the '
      'badge authenticates, kiosk_act carries the level', (tester) async {
    final reservations = await pumpKiosk(
      tester,
      bookableLevel: true,
      featureFlags: const {'levelBooking': true},
    );

    await tester.tap(find.byKey(const ValueKey('kiosk-level-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-9',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await confirmSummary(tester);

    final act = reservations.kioskActs.single;
    expect(act.action, 'check_in');
    expect(act.levelId, isNotNull);
    expect(act.seatId, isNull);
  });

  testWidgets(
      'no level button while the levelBooking feature is off (default) or '
      'the level is not bookable', (tester) async {
    await pumpKiosk(tester, bookableLevel: true);

    expect(find.byKey(const ValueKey('kiosk-level-button')), findsNothing);
  });

  testWidgets(
      'the camera reads the printed badge QR in the sheet (K3): the '
      'embedded scanner decodes and kiosk_act runs with the code',
      (tester) async {
    final qrScan = FakeQrScanner();
    final reservations = await pumpKiosk(tester, qrScan: qrScan);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();

    // The camera area is embedded in the badge sheet.
    expect(
      find.byKey(const ValueKey('kiosk-badge-camera')),
      findsOneWidget,
    );

    qrScan.emit('badge-token-cam');
    await tester.pumpAndSettle();
    await confirmSummary(tester);

    final act = reservations.kioskActs.single;
    expect(act.action, 'check_in');
    expect(act.badgeToken, 'badge-token-cam');
  });

  /// Opens the badge sheet (seat tap → Check in) for the status tests.
  Future<void> openBadgeSheet(WidgetTester tester) async {
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();
  }

  const nfcStatusKey = ValueKey('kiosk-nfc-status');

  testWidgets(
      'the badge sheet says the RFID reader is OFF in Android settings — '
      'the wall diagnosis for a present-but-disabled adapter',
      (tester) async {
    await pumpKiosk(
      tester,
      nfc: FakeNfcUidReader(deviceStatus: NfcStatus.off),
    );
    await openBadgeSheet(tester);

    expect(find.byKey(nfcStatusKey), findsOneWidget);
    expect(find.textContaining('Android settings'), findsOneWidget);
  });

  testWidgets(
      'the badge sheet says the tablet has NO NFC reader when the '
      'hardware is absent (the default fake)', (tester) async {
    await pumpKiosk(tester);
    await openBadgeSheet(tester);

    expect(find.byKey(nfcStatusKey), findsOneWidget);
    expect(find.textContaining('no NFC reader'), findsOneWidget);
  });

  testWidgets(
      'a session that will not start is surfaced instead of silently '
      'showing the tap icon over a dead reader', (tester) async {
    await pumpKiosk(
      tester,
      nfc: FakeNfcUidReader(available: true, startFails: true),
    );
    await openBadgeSheet(tester);

    expect(find.byKey(nfcStatusKey), findsOneWidget);
    expect(find.textContaining('did not start'), findsOneWidget);
    // No tap icon pretending the reader works.
    expect(find.byIcon(Icons.contactless_outlined), findsNothing);
  });

  testWidgets(
      'a working RFID reader shows the tap path and NO problem row',
      (tester) async {
    await pumpKiosk(tester, nfc: FakeNfcUidReader(available: true));
    await openBadgeSheet(tester);

    expect(find.byKey(nfcStatusKey), findsNothing);
    expect(find.byIcon(Icons.contactless_outlined), findsOneWidget);
  });

  testWidgets(
      'CARD MODE (field-proven fix): with NFC ready the camera stays '
      'DOWN — the exact environment card registration proved working — '
      'and one tap mounts it for QR badges', (tester) async {
    final nfc = FakeNfcUidReader(available: true);
    final qrScan = FakeQrScanner();
    final reservations =
        await pumpKiosk(tester, nfc: nfc, qrScan: qrScan);
    await openBadgeSheet(tester);

    // No camera streaming next to the armed NFC session.
    expect(find.byKey(const ValueKey('kiosk-badge-camera')), findsNothing);
    final scanButton = find.byKey(const ValueKey('kiosk-scan-qr-button'));
    expect(scanButton, findsOneWidget);

    // The QR path is one tap away and still completes the flow.
    await tester.tap(scanButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('kiosk-badge-camera')),
      findsOneWidget,
    );
    qrScan.emit('badge-token-cam');
    await tester.pumpAndSettle();
    await confirmSummary(tester);
    expect(reservations.kioskActs.single.badgeToken, 'badge-token-cam');
  });

  testWidgets(
      'without NFC the camera mounts directly — no extra tap for '
      'QR-only tablets', (tester) async {
    final qrScan = FakeQrScanner();
    await pumpKiosk(tester, qrScan: qrScan);
    await openBadgeSheet(tester);

    expect(
      find.byKey(const ValueKey('kiosk-badge-camera')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('kiosk-scan-qr-button')),
      findsNothing,
    );
  });

  testWidgets(
      'the summary names the identified member and the target; Reject '
      'discards — nothing runs and the readers stay off', (tester) async {
    final reservations = await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The résumé: who (identified from the badge) and where.
    expect(find.text('Flo'), findsOneWidget);
    expect(find.text('A1'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('kiosk-summary-reject')));
    await tester.pumpAndSettle();

    expect(reservations.kioskActs, isEmpty);
    expect(find.byKey(const ValueKey('kiosk-summary-name')), findsNothing);
  });

  testWidgets(
      'kioskMode OFF (hierarchy pass): a kiosk-flagged account behaves '
      'as a regular member — no gate, normal shell', (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'kioskMode': false},
    );
    workspace.myMember = workspace.myMember.copyWith(
      isAdmin: false,
      isOwner: false,
      isKiosk: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: plans,
          workspace: workspace,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kiosk-gate-title')), findsNothing);
    expect(find.byType(KioskScreen), findsNothing);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets(
      'the camera box carries a FLIP button that switches the lens '
      'preference on the spot (field request)', (tester) async {
    final frontCamera = InMemoryFrontCameraStore();
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
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
          workspace: workspace,
          qrScan: FakeQrScanner(),
          frontCamera: frontCamera,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-gate-start')));
    await tester.pumpAndSettle();
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();
    // #519 — the period step sits between action and badge.
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();

    expect(frontCamera.value, isTrue); // front by default
    await tester.tap(find.byKey(const ValueKey('scan-flip-camera')));
    await tester.pumpAndSettle();
    expect(frontCamera.value, isFalse);
  });

  // ---------------------------------------------------------------- #519
  // The period step: WHEN is chosen before the badge, granularity-true
  // and today-only; a reservation whose window already began can start
  // checked in through the same single badge presentation.

  Future<void> submitBadge(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('kiosk-badge-field')),
      'badge-token-1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'RESERVE, standing right there: the period step defaults to '
      '"check in right away" — one badge, the reservation starts '
      'CHECKED IN (#519)', (tester) async {
    final reservations = await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-reserve')));
    await tester.pumpAndSettle();

    // Time-based (flexible) granularity: From/To pickers, and the
    // check-in question because the window starts now.
    expect(find.byKey(const ValueKey('kiosk-period-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-period-end')), findsOneWidget);
    final swtch = find.byKey(const ValueKey('kiosk-period-checkin-now'));
    expect(swtch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(swtch).value, isTrue);

    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();
    await submitBadge(tester);

    // The summary is honest about the combined action.
    expect(find.text('Reserve & check in'), findsOneWidget);
    await confirmSummary(tester);

    final act = reservations.kioskActs.single;
    expect(act.action, 'check_in');
    // Today-only, never a past start: the window begins exactly now.
    expect(act.startsAt, kioskClock.now());
    expect(act.endsAt!.day, kTestNow.day);
  });

  testWidgets(
      'RESERVE with the check-in switch OFF stays a plain reservation '
      '(#519)', (tester) async {
    final reservations = await pumpKiosk(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-period-checkin-now')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();
    await submitBadge(tester);
    await confirmSummary(tester);

    expect(reservations.kioskActs.single.action, 'reserve');
  });

  testWidgets(
      'HALF-DAY granularity: chips instead of clocks; a running morning '
      'starts NOW, a future afternoon reserves plain (no check-in '
      'question) (#519)', (tester) async {
    final reservations =
        await pumpKiosk(tester, granularity: BookingGranularity.halfDay);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-reserve')));
    await tester.pumpAndSettle();

    // Day-part chips, morning (the running part at 10:00) preselected.
    expect(find.byKey(const ValueKey('kiosk-period-morning')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('kiosk-period-afternoon')), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-period-day')), findsOneWidget);
    expect(find.byKey(const ValueKey('kiosk-period-start')), findsNothing);

    // Pick the AFTERNOON: it starts later, so no check-in question.
    await tester
        .tap(find.byKey(const ValueKey('kiosk-period-afternoon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kiosk-period-checkin-now')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('kiosk-period-continue')));
    await tester.pumpAndSettle();
    await submitBadge(tester);
    await confirmSummary(tester);

    final act = reservations.kioskActs.single;
    expect(act.action, 'reserve');
    // The canonical afternoon window: boundary (12:00) → day end, today.
    expect(act.startsAt!.hour, 12);
    expect(act.startsAt!.isAfter(kioskClock.now()), isTrue);
    expect(act.endsAt!.hour, 17);
  });

  testWidgets(
      'CHECK-IN means being there: the start is pinned to now (time '
      'pickers) and a not-yet-started afternoon chip is disabled '
      '(half-days) (#519)', (tester) async {
    await pumpKiosk(tester);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kiosk-check-in')));
    await tester.pumpAndSettle();

    // Flexible granularity: the From button exists but is disabled.
    final startButton = find.byKey(const ValueKey('kiosk-period-start'));
    expect(
      tester.widget<OutlinedButton>(
        find.ancestor(
            of: find.byIcon(Icons.schedule_outlined),
            matching: find.byType(OutlinedButton)),
      ).onPressed,
      isNull,
    );
    expect(startButton, findsOneWidget);
  });
}
