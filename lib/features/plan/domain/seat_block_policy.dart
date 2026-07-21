// SPDX-License-Identifier: 0BSD
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';

/// Who may toggle a seat's maintenance block from the Plan screen (#161):
/// the (active) owner always; admins only when the owner switched the
/// adminSeatBlocking feature on; workers never. Mirrors the server-side
/// check of the set_seat_block RPC (migration 0021).
bool canManageSeatBlocks({
  required Member? member,
  required Set<WorkspaceFeature> features,
}) {
  if (member == null) return false;
  if (member.isOwner && member.status == MemberStatus.active) return true;
  return member.canAdminister &&
      features.contains(WorkspaceFeature.adminSeatBlocking);
}
