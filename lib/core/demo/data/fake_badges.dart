// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of Badges: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/badge_repository.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'fake_workspace_state.dart';
import 'fixture_clock.dart';

mixin FakeBadges on FakeWorkspaceState implements BadgeRepository {
  @override
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) async =>
      List.of(badges);
  @override
  Future<IssuedBadge> issueMemberBadge(
    String workspaceId,
    String memberId, {
    String label = '',
  }) async {
    final n = badges.length + 1;
    badges.add(
      MemberBadge(
        id: 'badge-$n',
        workspaceId: workspaceId,
        memberId: memberId,
        label: label,
        createdAt: kTestNow,
      ),
    );
    return (badgeId: 'badge-$n', token: 'badge-token-$n');
  }

  @override
  Future<void> registerNfcBadge(
    String workspaceId,
    String memberId, {
    required String uid,
    String label = '',
  }) async {
    // Duplicate-tag path (register_nfc_badge's pinned refusal, 0046).
    if (badges.any((b) => b.label == 'uid:$uid' && b.isActive)) {
      throw const PostgrestException(message: 'tag already registered');
    }
    badges.add(
      MemberBadge(
        id: 'badge-${badges.length + 1}',
        workspaceId: workspaceId,
        memberId: memberId,
        // The fake records the uid in the label so tests can assert it.
        label: label.isEmpty ? 'uid:$uid' : label,
        createdAt: kTestNow,
        kind: BadgeKind.nfc,
      ),
    );
  }

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    final i = badges.indexWhere((b) => b.id == badgeId);
    if (i >= 0) {
      badges[i] = badges[i].copyWith(revokedAt: kTestNow);
    }
  }

  /// (0053) Self-service paths — the fake reuses the admin bodies with
  /// the caller's own member id.
  @override
  Future<IssuedBadge> issueMyBadge(String workspaceId, {String label = ''}) =>
      issueMemberBadge(workspaceId, myMember.id, label: label);
  @override
  Future<void> registerMyNfcBadge(
    String workspaceId, {
    required String uid,
    String label = '',
  }) => registerNfcBadge(workspaceId, myMember.id, uid: uid, label: label);
  @override
  Future<void> revokeMyBadge(String badgeId) => revokeMemberBadge(badgeId);
  @override
  Future<void> deleteRevokedBadge(String badgeId) async {
    final before = badges.length;
    badges.removeWhere((b) => b.id == badgeId && !b.isActive);
    // Server contract (0055): live or unknown badges refuse.
    if (badges.length == before) {
      throw const PostgrestException(message: 'unknown badge');
    }
  }

  @override
  Future<bool> badgePinNeedsReview(String workspaceId, String memberId) async =>
      false;
}
