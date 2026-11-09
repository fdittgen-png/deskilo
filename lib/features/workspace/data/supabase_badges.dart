// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- member badges: issue, register, revoke, as one mixin composed into
// `SupabaseWorkspaceRepository` (the part-file bodies and their `_xxxImpl`
// forwarders are gone).

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/badge_repository.dart';
import '../domain/member_badge.dart';

mixin SupabaseBadges implements BadgeRepository {
  /// The client of the class this is mixed into.
  SupabaseClient get client;

  @override
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) async {
    final rows = await client
        .from('member_badges')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at', ascending: false);
    return rows.map(MemberBadge.fromRow).toList();
  }

  @override
  Future<IssuedBadge> issueMemberBadge(
    String workspaceId,
    String memberId, {
    String label = '',
  }) async {
    final result = await client.rpc<dynamic>(
      'issue_member_badge',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_label': label,
      },
    ) as Map<String, dynamic>;
    return (
      badgeId: result['badge_id'] as String,
      token: result['token'] as String,
    );
  }

  @override
  Future<IssuedBadge> issueMyBadge(
    String workspaceId, {
    String label = '',
  }) async {
    final result = await client.rpc<dynamic>(
      'issue_my_badge',
      params: {'p_workspace_id': workspaceId, 'p_label': label},
    ) as Map<String, dynamic>;
    return (
      badgeId: result['badge_id'] as String,
      token: result['token'] as String,
    );
  }

  @override
  Future<void> registerMyNfcBadge(
    String workspaceId, {
    required String uid,
    String label = '',
  }) async {
    await client.rpc<dynamic>(
      'register_my_nfc_badge',
      params: {'p_workspace_id': workspaceId, 'p_uid': uid, 'p_label': label},
    );
  }

  @override
  Future<void> revokeMyBadge(String badgeId) async {
    await client.rpc<dynamic>(
      'revoke_my_badge',
      params: {'p_badge_id': badgeId},
    );
  }

  @override
  Future<void> deleteRevokedBadge(String badgeId) async {
    await client.rpc<dynamic>(
      'delete_revoked_badge',
      params: {'p_badge_id': badgeId},
    );
  }

  @override
  Future<void> registerNfcBadge(
    String workspaceId,
    String memberId, {
    required String uid,
    String label = '',
  }) async {
    await client.rpc<dynamic>(
      'register_nfc_badge',
      params: {
        'p_workspace_id': workspaceId,
        'p_member_id': memberId,
        'p_uid': uid,
        'p_label': label,
      },
    );
  }

  @override
  Future<void> revokeMemberBadge(String badgeId) async {
    await client.rpc<dynamic>(
      'revoke_member_badge',
      params: {'p_badge_id': badgeId},
    );
  }

  @override
  Future<bool> badgePinNeedsReview(String workspaceId, String memberId) async =>
      await client.rpc<bool>(
        'badge_pin_needs_review',
        params: {'p_workspace_id': workspaceId, 'p_member_id': memberId},
      );
}
