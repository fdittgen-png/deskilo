// SPDX-License-Identifier: 0BSD
//
// Whole-level reservations (0050): the plan's reserve-level affordance is
// triple-gated (feature + level bookable + personal grant or assignment
// right); booking lands on the level target; owners/delegated admins
// assign to a member (confirmation flow); the members sheet toggles the
// per-member grant; the bill shows the level supplement.
//
// #638 — the affordance now opens the SHARED whole-space sheet instead of
// a second sheet of its own: the gates, the price line and the
// admin-for-member assignment are unchanged, and the period picker and
// series the level sheet never had come along for free.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<
    ({
      FakeReservationRepository reservations,
      FakeWorkspaceRepository workspace,
    })> pumpPlan(
  WidgetTester tester, {
  bool featureOn = true,
  bool bookable = true,
  bool canReserveLevel = true,
  bool isOwner = false,
  List<Member> others = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  if (bookable) {
    plans.levels[0] =
        plans.levels[0].copyWith(bookableAsWhole: true, priceCents: 2500);
  }
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: {
      if (featureOn) 'levelBooking': true,
    },
  );
  workspace.myMember = workspace.myMember.copyWith(
    isOwner: isOwner,
    isAdmin: isOwner,
    canReserveLevel: canReserveLevel,
  );
  workspace.otherMembers.addAll(others);
  for (final m in others) {
    workspace.memberNames[m.id] = 'Other ${m.id}';
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
  // The Reserve hub is home; the Plan tab hosts the reserve-level button.
  await switchToPlanTab(tester);
  return (reservations: reservations, workspace: workspace);
}

/// The converged path: layers icon → the shared whole-space sheet →
/// its Reserve action → the granularity-aware period picker.
Future<void> openLevelPeriodPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reserve-reserve-level')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('space-reserve')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a granted member reserves the whole level: button → shared sheet '
      'with the price → period picker → one level reservation',
      (tester) async {
    final ctx = await pumpPlan(tester);

    await tester.tap(find.byKey(const ValueKey('reserve-reserve-level')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('space-price-line')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-reserve')));
    await tester.pumpAndSettle();

    // #638 — the capability the level sheet never had: the window is
    // EDITABLE here, not a static line of text.
    expect(find.byKey(const ValueKey('booking-from-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-until-tile')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final r = ctx.reservations.reservations.single;
    expect(r.levelId, isNotNull);
    expect(r.seatId, isNull);
  });

  testWidgets('feature OFF hides the affordance entirely', (tester) async {
    await pumpPlan(tester, featureOn: false);

    expect(find.byKey(const ValueKey('reserve-reserve-level')), findsNothing);
  });

  testWidgets('a non-bookable level shows no affordance', (tester) async {
    await pumpPlan(tester, bookable: false);

    expect(find.byKey(const ValueKey('reserve-reserve-level')), findsNothing);
  });

  testWidgets('no grant and no assignment right → no affordance',
      (tester) async {
    await pumpPlan(tester, canReserveLevel: false);

    expect(find.byKey(const ValueKey('reserve-reserve-level')), findsNothing);
  });

  testWidgets(
      'the OWNER without the stored grant books the level for THEMSELF '
      '(#466 — the 0079 rule; the raw grant crashed the sheet when they '
      'were alone)', (tester) async {
    final ctx = await pumpPlan(
      tester,
      canReserveLevel: false,
      isOwner: true,
    );

    await openLevelPeriodPicker(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final r = ctx.reservations.reservations.single;
    expect(r.levelId, isNotNull);
  });

  testWidgets(
      'a plain granted member sees NO "for the member" selector (#638)',
      (tester) async {
    await pumpPlan(tester);

    await openLevelPeriodPicker(tester);

    expect(
      find.byKey(const ValueKey('booking-for-member')),
      findsNothing,
      reason: 'the selector belongs to the assignment right alone',
    );
  });

  testWidgets('the Reserve hub carries the same whole-level button (#466)',
      (tester) async {
    await pumpPlan(tester);
    // Back to the hub (centre button): the selector shows even with
    // one level because the affordance exists.
    await tester.tap(find.byTooltip('Reserve'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('reserve-reserve-level')), findsOneWidget);
  });

  testWidgets(
      'the owner assigns the level to another member — createFor carries '
      'the level and the pending-confirmation snack shows', (tester) async {
    const other = Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-2',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    );
    final ctx = await pumpPlan(
      tester,
      isOwner: true,
      canReserveLevel: false,
      others: [other],
    );

    await openLevelPeriodPicker(tester);

    await tester.tap(find.byKey(const ValueKey('booking-for-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other member-2').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send for confirmation'),
    );
    await tester.pumpAndSettle();

    final assigned = ctx.reservations.bookedForOthers.single;
    expect(assigned.subjectMemberId, 'member-2');
    expect(assigned.levelId, isNotNull);
    expect(assigned.seatId, isNull);
    expect(
      find.text('Sent to Other member-2 for confirmation.'),
      findsOneWidget,
    );
  });
}
