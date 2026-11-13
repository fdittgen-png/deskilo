// SPDX-License-Identifier: AGPL-3.0-or-later
// A personal read joins a workspace's memberships to its own money store.
import '../../features/workspace/domain/member.dart';
import 'data/money_repository.dart';
import 'data/workspace_repository.dart';

typedef DemoPersonalSpace = ({
  FakeWorkspaceRepository workspaces,
  FakeMoneyRepository money,
});

/// Membership ids are local to a workspace; account ids identify the person.
Iterable<Member> demoMembersOf(DemoPersonalSpace space) => [
  space.workspaces.myMember,
  ...space.workspaces.otherMembers,
].where((m) => m.workspaceId == space.workspaces.myMember.workspaceId);

Set<String> demoMemberIdsFor(DemoPersonalSpace space, String? userId) => {
  for (final member in demoMembersOf(space))
    if (userId != null &&
        userId.isNotEmpty &&
        member.userId == userId &&
        !member.isKiosk)
      member.id,
};
