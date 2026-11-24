// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- a billing customer's access to their own documents. The seller
// invites ONE financial subject (a billing customer, `members.id`) under
// manageBillingCustomers and is handed the code once; the account that holds the
// code previews what it names and accepts it; either side revokes. The grant is
// the login's separate, revocable link to the subject: no membership is created
// or changed, and a revocation erases nothing. Pure Dart: the repository (the
// RPCs of 0910) answers these shapes, the screens word the refusals.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// Where one grant stands, read from its own stamps.
enum BillingGrantState {
  /// Invited, not accepted yet, not expired.
  invited,

  /// Accepted and not revoked: the account reads the subject's documents.
  active,

  /// Invited and never accepted before it ran out.
  expired,

  /// Revoked by the seller or by the account.
  revoked,
}

/// One access grant as the seller reads it. The code is never part of it: the
/// server hands a code out once, with the invitation.
class BillingAccessGrant {
  const BillingAccessGrant({
    required this.id,
    required this.subjectId,
    required this.invitedAt,
    required this.expiresAt,
    this.acceptedAt,
    this.revokedAt,
    this.revokeReason = '',
  });

  factory BillingAccessGrant.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'billing access grant');
    return BillingAccessGrant(
      id: r.string('id'),
      subjectId: r.string('financial_subject_id'),
      invitedAt: r.dateTime('invited_at'),
      expiresAt: r.dateTime('expires_at'),
      acceptedAt: r.dateTimeOrNull('accepted_at'),
      revokedAt: r.dateTimeOrNull('revoked_at'),
      revokeReason: r.stringOr('revoke_reason'),
    );
  }

  final String id;

  /// The seller-local financial subject the grant reaches.
  final String subjectId;
  final DateTime invitedAt, expiresAt;
  final DateTime? acceptedAt, revokedAt;
  final String revokeReason;

  /// The state at [now].
  BillingGrantState stateAt(DateTime now) {
    if (revokedAt != null) return BillingGrantState.revoked;
    if (acceptedAt != null) return BillingGrantState.active;
    return expiresAt.isAfter(now)
        ? BillingGrantState.invited
        : BillingGrantState.expired;
  }
}

/// What an invitation answered: the code, shown once.
class BillingAccessInvitation {
  const BillingAccessInvitation({
    required this.grantId,
    required this.code,
    required this.expiresAt,
    this.replayed = false,
  });

  factory BillingAccessInvitation.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'billing access invitation');
    return BillingAccessInvitation(
      grantId: r.string('grant_id'),
      code: r.string('code'),
      expiresAt: r.dateTime('expires_at'),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }

  final String grantId, code;
  final DateTime expiresAt;

  /// The same request answered again: the same invitation, not a new one.
  final bool replayed;
}

/// What a code names, before it is accepted.
class BillingAccessPreview {
  const BillingAccessPreview({
    required this.workspaceName,
    required this.billedAs,
    required this.accepted,
    required this.expiresAt,
  });

  factory BillingAccessPreview.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'billing access preview');
    return BillingAccessPreview(
      workspaceName: r.stringOr('workspace_name'),
      billedAs: r.stringOr('billed_as'),
      accepted: r.boolOr('accepted', fallback: false),
      expiresAt: r.dateTime('expires_at'),
    );
  }

  /// The business that invites.
  final String workspaceName;

  /// The name or company the invoices are made out to; empty when unnamed.
  final String billedAs;

  /// This account holds it already (accepting again answers the same grant).
  final bool accepted;
  final DateTime expiresAt;
}

/// What accepting answered.
class BillingAccessAccepted {
  const BillingAccessAccepted({
    required this.grantId,
    required this.workspaceId,
    required this.subjectId,
    this.replayed = false,
  });

  factory BillingAccessAccepted.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'billing access accepted');
    return BillingAccessAccepted(
      grantId: r.string('grant_id'),
      workspaceId: r.string('workspace_id'),
      subjectId: r.string('financial_subject_id'),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }

  final String grantId, workspaceId, subjectId;
  final bool replayed;
}

/// Why the server refused, as a screen can say it.
enum BillingAccessRefusalKind {
  /// The caller lacks manageBillingCustomers, or is an assistant (DKN01, DKU02).
  notAllowed,

  /// The code is unknown, expired, revoked or taken by another account: one
  /// answer for all of them (DKH01), so a code cannot be probed.
  codeUnusable,

  /// The invitation names someone who is not a billing customer (DKH02).
  notACustomer,

  /// The grant is unknown (DKH03).
  unknownGrant,

  /// The reason is longer than the server keeps (DKH04).
  reasonTooLong,

  /// The request id was used for another invitation (DKH05).
  requestReused,

  /// Anything else the server refused.
  other,
}

class BillingAccessRefusal implements Exception {
  const BillingAccessRefusal(this.kind, {this.cause});

  final BillingAccessRefusalKind kind;
  final Object? cause;

  @override
  String toString() => 'BillingAccessRefusal($kind)';
}

/// The longest revocation reason the server keeps (`billing_access_grants`).
const int billingRevokeReasonMax = 500;

/// A code as the server compares it: trimmed, upper case.
String normaliseBillingCode(String raw) => raw.trim().toUpperCase();

/// The grants of 0910, over the seller's and the account's own doors.
abstract class BillingAccessRepository {
  /// The grants of [subjectId] in [workspaceId], newest first (the seller's
  /// read; the code is never part of it).
  Future<List<BillingAccessGrant>> grantsOf(
    String workspaceId,
    String subjectId,
  );

  /// Invites [subjectId]; the same [requestId] answers the same invitation.
  Future<BillingAccessInvitation> invite(
    String workspaceId,
    String subjectId,
    String requestId,
  );

  Future<BillingAccessPreview> preview(String code);

  Future<BillingAccessAccepted> accept(String code);

  /// Ends the grant's future access; nothing is erased.
  Future<void> revoke(String grantId, {String reason = ''});
}
