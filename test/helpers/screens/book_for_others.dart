// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in book_for_others_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_floor_plan_repository.dart';
import '../fake_reservation_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

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
Future<
  ({FakeReservationRepository reservations, FakeWorkspaceRepository workspace})
>
pumpPlanWithRoster(
  WidgetTester tester, {
  bool viewerIsOwner = true,
  void Function(FakeReservationRepository repo)? seedReservations,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository();
  seedReservations?.call(reservations);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana Lima'}
    ..otherMembers.add(ana)
    // Open every weekday so the closed-day gating (#186) never trips
    // when the suite runs on a weekend.
    ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
  if (!viewerIsOwner) {
    workspace.myMember = workspace.myMember.copyWith(
      isOwner: false,
      isAdmin: false,
    );
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
  await switchToPlanTab(tester);
  return (reservations: reservations, workspace: workspace);
}
