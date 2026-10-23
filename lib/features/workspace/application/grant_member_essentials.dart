// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2865 — since 0373 a plain member holds no everyday permission until the
// owner grants it, so every new space is born unable to take a booking.
// One tap grants the everyday set to the members role, permission by
// permission (#1089), so a concurrent change to another one survives.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/role_permission_repository.dart';
import '../domain/workspace_permission.dart';
import '../providers/workspace_providers.dart';

part 'grant_member_essentials.g.dart';

/// What a member needs to use the space day to day: book, see the
/// calendar, write to the others and see their own account.
const List<WorkspacePermission> memberEssentials = [
  WorkspacePermission.makeReservations,
  WorkspacePermission.viewCalendar,
  WorkspacePermission.useMessages,
  WorkspacePermission.viewMyMoney,
];

class MemberEssentialsGrant {
  const MemberEssentialsGrant(this._repository);
  final RolePermissionRepository _repository;

  /// Grants [memberEssentials] to the members role of [workspaceId].
  Future<void> grant(String workspaceId) async {
    for (final permission in memberEssentials) {
      await _repository.setRolePermission(
        workspaceId,
        PermissionRole.member.wireName,
        permission.wireName,
        enabled: true,
      );
    }
  }
}

/// #2865 — the one-tap member rights of the readiness card.
@riverpod
MemberEssentialsGrant memberEssentialsGrant(Ref ref) =>
    MemberEssentialsGrant(ref.watch(workspaceRepositoryProvider));
