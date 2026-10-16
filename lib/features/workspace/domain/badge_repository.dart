// SPDX-License-Identifier: AGPL-3.0-or-later
import 'member_badge.dart';

/// Member badges and NFC badges.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class BadgeRepository {
  /// Kiosk badges of the workspace (admin view; RLS also lets a member
  /// read their own).
  Future<List<MemberBadge>> fetchMemberBadges(String workspaceId);

  /// Admin-only (RPC `issue_member_badge`): mints a badge for [memberId]
  /// and returns the RAW token exactly once — render it as a QR and let
  /// it go; the server keeps only the hash.
  Future<IssuedBadge> issueMemberBadge(
    String workspaceId,
    String memberId, {
    String label,
  });

  /// Admin-only: revokes a badge (kiosks reject it from now on).
  Future<void> revokeMemberBadge(String badgeId);

  /// Self-service (RPC `issue_my_badge`, migration 0053): mints MY badge
  /// and returns the raw token exactly once — same one-time contract as
  /// the admin path.
  Future<IssuedBadge> issueMyBadge(String workspaceId, {String label});

  /// Self-service (RPC `register_my_nfc_badge`, 0053): registers a
  /// physical RFID/NFC tag as MY badge. Pinned duplicate substring:
  /// 'tag already registered'.
  Future<void> registerMyNfcBadge(
    String workspaceId, {
    required String uid,
    String label,
  });

  /// Self-service (RPC `revoke_my_badge`, 0053): revokes one of MY
  /// badges.
  Future<void> revokeMyBadge(String badgeId);

  /// Deletes a REVOKED badge for good (RPC `delete_revoked_badge`,
  /// migration 0055) — allowed to the badge's own member or a workspace
  /// admin; live badges must be revoked first.
  Future<void> deleteRevokedBadge(String badgeId);

  /// Admin-only (RPC `register_nfc_badge`, migration 0046): registers a
  /// physical RFID/NFC tag as [memberId]'s badge. [uid] is the tag UID as
  /// lowercase hex (the reader normalizes it); the server keeps only the
  /// hash. A UID registers at most once per workspace — re-registration
  /// raises with the pinned substring 'tag already registered'.
  Future<void> registerNfcBadge(
    String workspaceId,
    String memberId, {
    required String uid,
    String label,
  });
}
