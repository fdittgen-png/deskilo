// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — what the server said about one invitation (0309): a preview
// before Join, and the typed result after it. Parsed defensively: a state
// this build does not know is `unknown`, never a success.
import 'invite_uri.dart';
import 'member.dart';

enum InvitationState {
  /// Usable: the preview's workspace, role and approval are real.
  valid,

  /// Joined; the membership is active.
  joinedActive,

  /// Joined; the membership awaits the workspace's approval.
  joinedPending,

  /// This account already has an active or pending membership there.
  alreadyMember,

  /// This account's membership there is paused; a code does not undo it.
  paused,

  /// A personal invitation past its expiry.
  expired,

  /// A workspace code the owner has since replaced.
  revoked,

  /// A personal invitation already used by, or bound to, another account.
  wrongAccount,

  /// No workspace on this server knows the code.
  invalid,

  /// A newer server's answer this build cannot read.
  unknown,
}

class InvitationAnswer {
  const InvitationAnswer(
    this.state, {
    this.workspaceId,
    this.workspaceName,
    this.environment,
    this.offeredRole,
    this.requiresApproval,
    this.memberStatus,
  });

  factory InvitationAnswer.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, Object?>{};
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final state = switch (json['state']) {
      'valid' => InvitationState.valid,
      'joined_active' => InvitationState.joinedActive,
      'joined_pending' => InvitationState.joinedPending,
      'already_member' => InvitationState.alreadyMember,
      'paused' => InvitationState.paused,
      'expired' => InvitationState.expired,
      'revoked' => InvitationState.revoked,
      'wrong_account' => InvitationState.wrongAccount,
      'invalid' => InvitationState.invalid,
      _ => InvitationState.unknown,
    };
    return InvitationAnswer(
      state,
      workspaceId: text('workspace_id'),
      workspaceName: text('workspace_name'),
      environment: text('environment'),
      offeredRole: switch (json['offered_role']) {
        'admin' => InviteRole.admin,
        'member' => InviteRole.user,
        _ => null,
      },
      requiresApproval: json['requires_approval'] is bool
          ? json['requires_approval'] as bool
          : null,
      memberStatus: switch (json['member_status']) {
        'active' => MemberStatus.active,
        'pending' => MemberStatus.pending,
        'paused' => MemberStatus.paused,
        _ => null,
      },
    );
  }

  final InvitationState state;
  final String? workspaceId;
  final String? workspaceName;
  final String? environment;

  /// Null when the server did not say: shown as unknown, never guessed.
  final InviteRole? offeredRole;
  final bool? requiresApproval;
  final MemberStatus? memberStatus;

  /// A membership exists now and the workspace may be opened: active, or
  /// pending (the router then shows the waiting screen for it).
  bool get opensWorkspace =>
      workspaceId != null &&
      (state == InvitationState.joinedActive ||
          state == InvitationState.joinedPending ||
          (state == InvitationState.alreadyMember &&
              (memberStatus == MemberStatus.active ||
                  memberStatus == MemberStatus.pending)));
}
