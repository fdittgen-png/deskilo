// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import 'overage_policy.dart';

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

    /// What happens once the member has used their whole monthly
    /// entitlement (migration 0041): blocked (default), pay-as-you-go, or
    /// buy-a-package.
    @Default(OveragePolicy.blocked) OveragePolicy overagePolicy,

    /// Wall-mounted tablet account (migration 0043): the app locks to the
    /// plan view; real members act through it by presenting a badge.
    @Default(false) bool isKiosk,

    /// Cap on simultaneous open reservations (migration 0044): at most
    /// this many bookings with status reserved/checked-in that have not
    /// ended yet. Null = unlimited. Set by owner/admins for OTHERS only —
    /// never self-service.
    int? maxActiveReservations,
  }) = _Member;

  /// Admin capability (owners inherit it, spec §2).
  bool get canAdminister => (isAdmin || isOwner) && status == MemberStatus.active;
}
