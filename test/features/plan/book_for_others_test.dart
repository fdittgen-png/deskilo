// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';
import 'plan_screen_test.dart' show seatCenter;

const ana = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

/// Like pumpPlan, but the member roster is seeded BEFORE pumping so the
/// members provider sees it (#106).
Future<({FakeReservationRepository reservations, FakeWorkspaceRepository workspace})>
    pumpPlanWithRoster(
  WidgetTester tester, {
  bool viewerIsOwner = true,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    ..otherMembers.add(ana);
  if (!viewerIsOwner) {
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
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
  return (reservations: reservations, workspace: workspace);
}

void main() {
  testWidgets('an owner books a seat for another member (#106)',
      (tester) async {
    final env = await pumpPlanWithRoster(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // The admin-only picker defaults to self.
    await tester.tap(find.text('Flo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Lima').last);
    await tester.pumpAndSettle();

    // Booking for someone else is a confirmation request, not a check-in.
    expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Send for confirmation'),
    );
    await tester.pumpAndSettle();

    final call = env.reservations.bookedForOthers.single;
    expect(call.subjectMemberId, 'member-2');
    expect(call.seatId, 'seat-4');
    expect(
      find.text('Sent to Ana Lima for confirmation.'),
      findsOneWidget,
    );
  });

  testWidgets('booking for yourself through the picker stays a walk-up',
      (tester) async {
    final env = await pumpPlanWithRoster(tester);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    expect(env.reservations.bookedForOthers, isEmpty);
    expect(env.reservations.reservations.single.memberId, 'member-1');
  });

  testWidgets('workers get no member picker', (tester) async {
    await pumpPlanWithRoster(tester, viewerIsOwner: false);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.text('Book for'), findsNothing);
  });
}
