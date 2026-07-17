// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import 'plan_screen_test.dart' show seatCenter;

/// Pumps the Plan tab with the seeded small plan (#161 harness). The
/// default viewer is the owner (standard overrides); [viewerIsAdminOnly]
/// demotes them to a non-owner admin; [featureFlags] seeds the workspace
/// feature overrides (adminSeatBlocking defaults OFF, #161).
Future<FakeFloorPlanRepository> pumpPlanForBlocking(
  WidgetTester tester, {
  bool viewerIsAdminOnly = false,
  Map<String, dynamic> featureFlags = const {},
  bool seatBlocked = false,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (seatBlocked) {
    final seat = plans.seats.single;
    plans.seats[0] = seat.copyWith(
      blockedFrom: DateTime.now().subtract(const Duration(days: 1)),
    );
  }
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        // Open every weekday so the closed-day gating (#186) never trips
        // when the suite runs on a weekend.
        ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
  if (viewerIsAdminOnly) {
    workspace.myMember = workspace.myMember.copyWith(isOwner: false);
  }
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
  await switchToPlanTab(tester);
  return plans;
}

void main() {
  group('FakeFloorPlanRepository.setSeatBlock', () {
    test('records the call and updates the seat', () async {
      final plans = FakeFloorPlanRepository()..seedSmallPlan();
      final seat = plans.seats.single;
      final from = DateTime.utc(2026, 7, 11, 9);

      await plans.setSeatBlock(seat.id, from: from);

      expect(
        plans.lastSeatBlock,
        (seatId: seat.id, from: from, to: null),
      );
      expect(plans.seats.single.blockedFrom, from);
      expect(plans.seats.single.blockedTo, isNull);
      expect(plans.seats.single.isBlockedAt(DateTime.utc(2030)), isTrue);

      await plans.setSeatBlock(seat.id);

      expect(plans.seats.single.blockedFrom, isNull);
      expect(plans.seats.single.isBlockedAt(DateTime.utc(2030)), isFalse);
    });

    test('throws on an unknown seat', () async {
      final plans = FakeFloorPlanRepository()..seedSmallPlan();

      expect(
        () => plans.setSeatBlock('seat-nope', from: DateTime.utc(2026)),
        throwsStateError,
      );
    });
  });

  testWidgets(
      'the owner makes a free seat not reservable from the booking sheet',
      (tester) async {
    final plans = await pumpPlanForBlocking(tester);
    final before = DateTime.now();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Make not reservable'));
    await tester.tap(find.text('Make not reservable'));
    await tester.pumpAndSettle();

    final call = plans.lastSeatBlock;
    expect(call, isNotNull);
    expect(call!.seatId, 'seat-4');
    // Open-ended block: from ~now, no end.
    expect(call.from, isNotNull);
    expect(call.from!.isBefore(before.toUtc()), isFalse);
    expect(call.to, isNull);
    expect(plans.seats.single.isBlockedAt(DateTime.now()), isTrue);
  });

  testWidgets('the owner makes a blocked seat reservable again',
      (tester) async {
    final plans = await pumpPlanForBlocking(tester, seatBlocked: true);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The sheet still explains the block…
    expect(
      find.text('This seat is blocked for maintenance.'),
      findsOneWidget,
    );

    // …and clearing it wipes both bounds.
    await tester.tap(find.text('Make reservable'));
    await tester.pumpAndSettle();

    expect(
      plans.lastSeatBlock,
      (seatId: 'seat-4', from: null, to: null),
    );
    expect(plans.seats.single.isBlockedAt(DateTime.now()), isFalse);
  });

  testWidgets('an admin without the feature gets no blocking affordances',
      (tester) async {
    await pumpPlanForBlocking(tester, viewerIsAdminOnly: true);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Make not reservable'), findsNothing);
  });

  testWidgets(
      'an admin without the feature only gets the explanation on a '
      'blocked seat', (tester) async {
    await pumpPlanForBlocking(
      tester,
      viewerIsAdminOnly: true,
      seatBlocked: true,
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(
      find.text('This seat is blocked for maintenance.'),
      findsOneWidget,
    );
    expect(find.text('Make reservable'), findsNothing);
  });

  testWidgets('an admin WITH the feature blocks a seat (#161)',
      (tester) async {
    final plans = await pumpPlanForBlocking(
      tester,
      viewerIsAdminOnly: true,
      featureFlags: const {'adminSeatBlocking': true},
    );

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Make not reservable'));
    await tester.tap(find.text('Make not reservable'));
    await tester.pumpAndSettle();

    expect(plans.lastSeatBlock?.seatId, 'seat-4');
    expect(plans.lastSeatBlock?.to, isNull);
    expect(plans.seats.single.isBlockedAt(DateTime.now()), isTrue);
  });
}
