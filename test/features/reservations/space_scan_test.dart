// SPDX-License-Identifier: 0BSD
//
// Space QR codes (field request): every desk, office and level carries a
// printable QR; scanning it (camera or typed) opens the space sheet with
// exactly the actions this member may take — reserve or check in on the
// spot, whole office/level only with feature + bookable + grant.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/space_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  test('codec: encode/decode roundtrip for every kind; foreign payloads '
      'decode to null', () {
    for (final kind in SpaceKind.values) {
      final payload = SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: kind,
        id: 'x-1',
      );
      final decoded = SpaceCodeCodec.decode(' $payload ');
      expect(decoded, isNotNull);
      expect(decoded!.workspaceId, 'ws-1');
      expect(decoded.kind, kind);
      expect(decoded.id, 'x-1');
    }
    expect(SpaceCodeCodec.decode('https://example.com/x'), isNull);
    expect(SpaceCodeCodec.decode('deskilo://join?code=ABC'), isNull);
    expect(
      SpaceCodeCodec.decode('deskilo://space?ws=ws-1&kind=sofa&id=x'),
      isNull,
    );
    expect(SpaceCodeCodec.decode('deskilo://space?ws=ws-1&kind=desk'),
        isNull);
    expect(SpaceCodeCodec.decode('not a uri at all'), isNull);
    // #584 — embedded info params ride along without breaking decode.
    final informed = SpaceCodeCodec.encode(
      workspaceId: 'ws-1',
      kind: SpaceKind.seat,
      id: 's-1',
      info: {'workspace': 'Pézenas', 'chair': 'A1'},
    );
    expect(informed, contains('chair=A1'));
    final decodedInformed = SpaceCodeCodec.decode(informed);
    expect(decodedInformed!.kind, SpaceKind.seat);
    expect(decodedInformed.id, 's-1');
  });

  /// Pumps the hub, opens the scanner and submits [payload] typed.
  Future<
      ({
        FakeReservationRepository reservations,
        FakeFloorPlanRepository plans,
        FakeWorkspaceRepository workspace,
      })> pumpAndScan(
    WidgetTester tester,
    String Function(FakeFloorPlanRepository plans) payload, {
    Map<String, dynamic> featureFlags = const {},
    bool granted = false,
    bool officeBookable = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    if (officeBookable) {
      plans.offices[0] = plans.offices[0]
          .copyWith(bookableAsWhole: true, priceCents: 2500);
    }
    final reservations = FakeReservationRepository();
    final workspace =
        FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
          ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    if (granted) {
      workspace.myMember =
          workspace.myMember.copyWith(canReserveLevel: true);
    }
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
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-scan-field')),
      payload(plans),
    );
    await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
    await tester.pumpAndSettle();
    return (
      reservations: reservations,
      plans: plans,
      workspace: workspace
    );
  }

  String deskPayload(FakeFloorPlanRepository plans) => SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.desk,
        id: plans.desks.single.id,
      );

  String officePayload(FakeFloorPlanRepository plans) =>
      SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.office,
        id: plans.offices.single.id,
      );

  testWidgets(
      'WORKSTATION card: scanning a seat QR goes straight to that seat — '
      'named with its desk — and checks in on the spot', (tester) async {
    final env = await pumpAndScan(
      tester,
      (plans) => SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.seat,
        id: plans.seats.single.id,
      ),
    );

    // Seat and desk on the title — tables share seat letters.
    expect(find.text('A1 · Window desk'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('space-seat-${env.plans.seats.single.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-act-checkin')));
    await tester.pumpAndSettle();

    expect(
      env.reservations.reservations.single.seatId,
      env.plans.seats.single.id,
    );
  });

  testWidgets(
      'desk card: the sheet lists the desk seats; a free seat checks in '
      'on the spot', (tester) async {
    final env = await pumpAndScan(tester, deskPayload);

    // The desk sheet names the desk and its seat.
    expect(find.text('Window desk'), findsOneWidget);
    final seatRow = find.byKey(
      ValueKey('space-seat-${env.plans.seats.single.id}'),
    );
    expect(seatRow, findsOneWidget);

    await tester.tap(seatRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('space-act-checkin')));
    await tester.pumpAndSettle();

    final r = env.reservations.reservations.single;
    expect(r.seatId, env.plans.seats.single.id);
    expect(find.textContaining('all set'), findsOneWidget);
  });

  testWidgets(
      'office card WITHOUT feature/grant: no whole-space buttons — the '
      'sheet explains and falls back to the seats', (tester) async {
    final env = await pumpAndScan(tester, officePayload,
        officeBookable: true);

    expect(find.byKey(const ValueKey('space-reserve')), findsNothing);
    expect(find.byKey(const ValueKey('space-checkin')), findsNothing);
    expect(
      find.byKey(const ValueKey('space-not-allowed')),
      findsOneWidget,
    );
    // The office's seats stay bookable.
    expect(
      find.byKey(ValueKey('space-seat-${env.plans.seats.single.id}')),
      findsOneWidget,
    );
  });

  testWidgets(
      'office card with feature + bookable + grant: whole-office check-in '
      'creates the office reservation', (tester) async {
    final env = await pumpAndScan(
      tester,
      officePayload,
      featureFlags: const {'levelBooking': true},
      granted: true,
      officeBookable: true,
    );

    await tester.tap(find.byKey(const ValueKey('space-checkin')));
    await tester.pumpAndSettle();

    final r = env.reservations.reservations.single;
    expect(r.officeId, env.plans.offices.single.id);
    expect(r.seatId, isNull);
  });

  testWidgets(
      'a reserved seat inside blocks the whole office: buttons disabled '
      'with the conflict note, the taken seat row is disabled too',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    plans.offices[0] =
        plans.offices[0].copyWith(bookableAsWhole: true);
    final reservations = FakeReservationRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'levelBooking': true},
    )..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    workspace.myMember =
        workspace.myMember.copyWith(canReserveLevel: true);
    // Someone holds the seat NOW — seeded before the pump so the day's
    // reservation providers see it from the first fetch.
    await reservations.create(
      workspaceId: 'ws-1',
      seatId: plans.seats.single.id,
      startsAt: kTestNow.subtract(const Duration(minutes: 5)),
      endsAt: kTestNow.add(const Duration(hours: 2)),
    );
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
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-scan-field')),
      SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.office,
        id: plans.offices.single.id,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-conflict')), findsOneWidget);
    final checkIn = tester.widget<FilledButton>(
      find.byKey(const ValueKey('space-checkin')),
    );
    expect(checkIn.onPressed, isNull);
    expect(find.text('Taken'), findsOneWidget);
  });

  testWidgets(
      'a foreign QR shows the inline error and the scanner stays open',
      (tester) async {
    await pumpAndScan(tester, (_) => 'https://example.com/whatever');

    expect(
      find.text('Not a space code of this workspace.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('space-scan-field')), findsOneWidget);
  });

  testWidgets(
      'the camera decodes a level card: the whole-level actions appear '
      'when feature + bookable + grant hold (K3 seam)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    plans.levels[0] = plans.levels[0]
        .copyWith(bookableAsWhole: true, priceCents: 10000);
    final reservations = FakeReservationRepository();
    final qrScan = FakeQrScanner();
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'levelBooking': true},
    )..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    workspace.myMember =
        workspace.myMember.copyWith(canReserveLevel: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: plans,
          reservations: reservations,
          workspace: workspace,
          qrScan: qrScan,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('space-scan-camera')),
      findsOneWidget,
    );

    qrScan.emit(SpaceCodeCodec.encode(
      workspaceId: 'ws-1',
      kind: SpaceKind.level,
      id: plans.levels.single.id,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ground floor'), findsOneWidget);
    // 0065 — Reserve opens the period/repeat picker; confirming books.
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final r = reservations.reservations.single;
    expect(r.levelId, plans.levels.single.id);
  });

  testWidgets(
      'spaceQrCodes OFF (hierarchy pass): the hub shows no scan button',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'spaceQrCodes': false},
          ),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reserve-scan-button')), findsNothing);
  });

  testWidgets(
      'DESK card with feature + bookable + grant: whole-desk check-in '
      'creates the desk reservation (0059)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    plans.desks[0] =
        plans.desks[0].copyWith(bookableAsWhole: true, priceCents: 1500);
    final reservations = FakeReservationRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace(
      featureFlags: const {'levelBooking': true},
    )..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    workspace.myMember =
        workspace.myMember.copyWith(canReserveLevel: true);
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
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('space-scan-field')),
      SpaceCodeCodec.encode(
        workspaceId: 'ws-1',
        kind: SpaceKind.desk,
        id: plans.desks.single.id,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('space-scan-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('space-checkin')));
    await tester.pumpAndSettle();

    final r = reservations.reservations.single;
    expect(r.deskId, plans.desks.single.id);
    expect(r.seatId, isNull);
  });

  // ── chair NFC tags (#585) ──────────────────────────────────────────

  /// Pumps the hub with an NFC-capable device and opens the scanner.
  Future<({FakeFloorPlanRepository plans, FakeNfcUidReader nfc})>
      pumpNfcScanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.single;
    plans.seats[0] = seat.copyWith(nfcUid: 'aabbccdd');
    final nfc = FakeNfcUidReader(available: true);
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [1, 2, 3, 4, 5, 6, 7];
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          floorPlan: plans,
          reservations: FakeReservationRepository(),
          workspace: workspace,
          nfc: nfc,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reserve-scan-button')));
    await tester.pumpAndSettle();
    return (plans: plans, nfc: nfc);
  }

  testWidgets(
      'tapping a linked chair tag resolves to that seat like its QR '
      '(#585)', (tester) async {
    final env = await pumpNfcScanner(tester);

    // The scanner advertises the tap path on NFC-capable devices.
    expect(find.byKey(const ValueKey('space-scan-nfc-hint')),
        findsOneWidget);

    env.nfc.tap('aabbccdd');
    await tester.pumpAndSettle();

    // Straight to the seat's space sheet, named with its desk.
    expect(find.text('A1 · Window desk'), findsOneWidget);
  });

  testWidgets('an unlinked tag reports and keeps the scanner open',
      (tester) async {
    final env = await pumpNfcScanner(tester);

    env.nfc.tap('deadbeef');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-scan-unknown-tag')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('space-scan-field')),
        findsOneWidget);
  });

  test('the fake mirrors the 0114 unique index: one tag, one chair',
      () async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.single;
    plans.seats[0] = seat.copyWith(nfcUid: 'aabbccdd');
    await plans.createSeat(
      workspaceId: seat.workspaceId,
      deskId: seat.deskId,
      name: 'B1',
      x: 20,
      y: 0,
      orientation: seat.orientation,
    );
    final other = plans.seats.last;
    await expectLater(
      plans.updateSeat(other.copyWith(nfcUid: 'aabbccdd')),
      throwsA(isA<Object>()),
    );
    expect(
      await plans.seatIdForNfcUid(seat.workspaceId, 'aabbccdd'),
      seat.id,
    );
    expect(await plans.seatIdForNfcUid(seat.workspaceId, 'ffff0000'),
        isNull);
  });
}
