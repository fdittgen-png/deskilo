// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member.freezed.dart';

/// Membership status (spec §7.2). Enum values are persisted by name —
/// never rename.
enum MemberStatus { active, paused, exited }

/// A user's participation in one workspace. Roles are additive flags
/// (spec §2): every member is a worker; admin/owner add capabilities.
@freezed
sealed class Member with _$Member {
  const Member._();

  const factory Member({
    required String id,
    required String workspaceId,
    required String userId,
    required bool isAdmin,
    required bool isOwner,
    required MemberStatus status,
    /// Subscription percentage 1–100 (ADR 0008): the membership level the
    /// fee band and the half-day entitlement derive from.
    @Default(100) int subscriptionPct,
  }) = _Member;

  /// Admin capability (owners inherit it, spec §2).
  bool get canAdminister => (isAdmin || isOwner) && status == MemberStatus.active;
}
