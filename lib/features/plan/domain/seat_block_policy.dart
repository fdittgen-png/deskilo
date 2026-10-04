// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';

/// Who may toggle a seat's maintenance block from the Plan screen (#161):
/// the (active) owner always; admins only when the owner switched the
/// adminSeatBlocking feature on; workers never. Mirrors the server-side
/// check of the set_seat_block RPC (migration 0021), which asks
/// manageReservations — so, since #2137, [staff] (an admin, or that
/// permission through a role: actsForReservations) counts as an admin.
bool canManageSeatBlocks({
  required Member? member,
  required Set<WorkspaceFeature> features,
  bool staff = false,
}) {
  if (member == null) return false;
  if (member.actsAsOwner) return true;
  return (member.canAdminister ||
          (staff && member.status == MemberStatus.active)) &&
      features.contains(WorkspaceFeature.adminSeatBlocking);
}
