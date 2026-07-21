// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_badge.freezed.dart';

/// How the badge credential is presented (migration 0046). Persisted by
/// name — never rename.
enum BadgeKind {
  /// A server-minted secret rendered as a QR (scan or type its code).
  qr,

  /// A physical RFID/NFC tag; the credential is its normalized UID.
  nfc;

  static BadgeKind fromName(String? name) =>
      BadgeKind.values.where((k) => k.name == name).firstOrNull ??
      BadgeKind.qr;
}

/// A member's kiosk badge (migration 0043): the QR/barcode (or NFC tag)
/// a member presents at a wall-mounted kiosk to reserve or check in as
/// themselves. The server stores only the token's SHA-256 hash — the raw
/// token exists client-side exactly once, in [IssuedBadge.token].
@freezed
sealed class MemberBadge with _$MemberBadge {
  const MemberBadge._();

  const factory MemberBadge({
    required String id,
    required String workspaceId,
    required String memberId,
    required String label,
    required DateTime createdAt,
    DateTime? revokedAt,
    @Default(BadgeKind.qr) BadgeKind kind,
  }) = _MemberBadge;

  factory MemberBadge.fromRow(Map<String, dynamic> row) => MemberBadge(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        memberId: row['member_id'] as String,
        label: row['label'] as String? ?? '',
        createdAt: DateTime.parse(row['created_at'] as String),
        revokedAt: row['revoked_at'] == null
            ? null
            : DateTime.parse(row['revoked_at'] as String),
        kind: BadgeKind.fromName(row['kind'] as String?),
      );

  bool get isActive => revokedAt == null;
}

/// The one-time result of issuing a badge: the id plus the RAW token to
/// render as a QR — never persisted client-side, never recoverable later.
typedef IssuedBadge = ({String badgeId, String token});
