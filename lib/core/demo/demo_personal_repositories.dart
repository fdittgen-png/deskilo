// SPDX-License-Identifier: AGPL-3.0-or-later
// The personal home and history follow the account signed into the demo,
// even when the visitor switches personas without rebuilding repositories.
import '../../features/me/domain/personal_workspace_refs.dart';
import '../../features/workspace/domain/member.dart';
import 'data/account_activity_repository.dart';
import 'data/me_repository.dart';
import 'demo_finance_projection.dart';
import 'demo_personal_activity.dart';
import 'demo_personal_space.dart';
import 'demo_space_routing.dart';

FakeAccountActivityRepository demoPersonalActivity({
  required List<DemoPersonalSpace> Function() spaces,
  required String? Function() currentUser,
}) => FakeAccountActivityRepository(
  derive: () => demoFinanceForUser(spaces(), currentUser()),
  deriveRecords: (kind) => demoPersonalHistory(spaces(), currentUser(), kind),
);

FakeMeRepository demoPersonalMe({
  required List<DemoPersonalSpace> Function() spaces,
  required String? Function() currentUser,
}) => FakeMeRepository(
  currentUser: () => currentUser() ?? '',
  homeInstallationId: kDemoInstallationId,
  accounts: _accounts(spaces()),
  deriveWorkspaceRefs: () => _references(spaces(), currentUser()),
);

Map<String, FakeAccount> _accounts(List<DemoPersonalSpace> spaces) {
  final accounts = <String, FakeAccount>{};
  for (final space in spaces) {
    for (final member in demoMembersOf(space)) {
      if (member.isKiosk || member.userId.isEmpty) continue;
      final account = accounts.putIfAbsent(
        member.userId,
        () => FakeAccount(
          name: space.workspaces.memberNames[member.id] ?? member.managedName,
          email: space.workspaces.memberEmails[member.id] ?? '',
          spaces: {},
        ),
      );
      if (member.status == MemberStatus.active) {
        account.spaces.add(member.workspaceId);
      }
    }
  }
  return accounts;
}

PersonalWorkspaceRefs _references(
  List<DemoPersonalSpace> spaces,
  String? userId,
) => PersonalWorkspaceRefs(
  homeInstallationId: kDemoInstallationId,
  refs: [
    for (final space in spaces)
      for (final member in demoMembersOf(space))
        if (userId != null &&
            userId.isNotEmpty &&
            member.userId == userId &&
            !member.isKiosk)
          PersonalWorkspaceRef(
            networkId: '$kDemoInstallationId:${member.workspaceId}',
            hostedHere: true,
            freshness: RefFreshness.local,
            status: RefStatus.values.byName(member.status.name),
            label: space.workspaces.workspaces
                .where((w) => w.id == member.workspaceId)
                .firstOrNull
                ?.name,
          ),
  ],
);
