// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of WorkspaceMembers: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_term_change.dart';
import 'package:deskilo/features/workspace/domain/membership_repository.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'fake_workspace_state.dart';

mixin FakeWorkspaceMembers on FakeWorkspaceState
    implements MembershipRepository {
  /// Mirrors the server rules (0051): admins mint member invites, only
  /// owners mint admin invites.
  @override
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',
    String? memberId,
    bool alsoProd = false,
  }) async {
    if (isAdmin && !myMember.isOwner) {
      throw const PostgrestException(
          message: 'only owners may invite admins', code: 'DKN01');
    }
    if (!isAdmin && !myMember.isAdmin) {
      throw const PostgrestException(
          message: 'only admins may invite members', code: 'DKN01');
    }
    final code = 'INVITE${nextInviteCode++}Z';
    mintedInvitations.add((
      code: code,
      isAdmin: isAdmin,
      firstName: firstName,
      lastName: lastName,
      memberId: memberId,
      alsoProd: alsoProd,
    ));
    return code;
  }

  @override
  Future<void> decideMemberJoin(
    String memberId, {
    required bool approve,
    String comment = '',
    String? expectedAccount,
  }) async {
    joinDecisions[memberId] = approve;
    joinComments[memberId] = comment;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      otherMembers[i] = otherMembers[i].copyWith(
        status: approve ? MemberStatus.active : MemberStatus.exited,
      );
    }
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(
        status: approve ? MemberStatus.active : MemberStatus.exited,
      );
    }
  }

  @override
  Future<String> joinWorkspace(String inviteCode) async {
    final invitation = mintedInvitations
        .where((i) => i.code == inviteCode)
        .firstOrNull;
    var joinAsAdmin = false;
    if (invitation != null) {
      if (!redeemedInvitations.add(inviteCode)) {
        throw StateError('invalid invite code');
      }
      joinAsAdmin = invitation.isAdmin;
    } else if (inviteCode != 'GOODCODE22') {
      throw StateError('invalid invite code');
    }
    final workspace = Workspace(
      id: 'ws-joined-${nextId++}',
      rolePermissions: everydayMatrix(),
      name: 'Joined Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: inviteCode,
    );
    workspaces.add(workspace);
    if (joinsArePending) {
      // Server truth since 0052: the joined membership awaits validation.
      myMember = myMember.copyWith(
        workspaceId: workspace.id,
        status: MemberStatus.pending,
        isAdmin: joinAsAdmin,
        isOwner: false,
      );
    }
    return workspace.id;
  }

  @override
  Future<InvitationAnswer> previewInvitation(String inviteCode) async {
    previewCalls++;
    return invitationState(inviteCode.trim().toUpperCase());
  }

  @override
  Future<InvitationAnswer> joinByInvitation(String inviteCode) async {
    joinByInvitationCalls++;
    final code = inviteCode.trim().toUpperCase();
    final before = invitationState(code);
    if (before.state != InvitationState.valid) return before;
    final id = await joinWorkspace(code);
    joinedByCode[code] = id;
    final status = myMember.workspaceId == id
        ? myMember.status
        : MemberStatus.active;
    return InvitationAnswer(
      status == MemberStatus.pending
          ? InvitationState.joinedPending
          : InvitationState.joinedActive,
      workspaceId: id,
      workspaceName: 'Joined Space',
      environment: 'dev',
      offeredRole: before.offeredRole,
      memberStatus: status,
    );
  }

  @override
  Future<void> setInvitationTemplate(
    String workspaceId,
    String template,
  ) async {
    lastInvitationTemplate = template;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i != -1) {
      workspaces[i] = workspaces[i].copyWith(invitationTemplate: template);
    }
  }

  @override
  Future<Member?> fetchMyMember(String workspaceId) async =>
      [
        myMember,
        ...extraMyMemberships,
      ].where((m) => m.workspaceId == workspaceId).firstOrNull ??
      myMember.copyWith(workspaceId: workspaceId);
  @override
  Future<Map<String, String>> fetchMemberNames(String workspaceId) async => {
    ...memberNames,
    // #887 — a managed member is named from its identity, as the
    // server does.
    for (final m in otherMembers)
      if (m.isManaged) m.id: m.managedIdentity.fullName,
  };
  @override
  Future<Map<String, String>> fetchMemberEmails(String workspaceId) async =>
      (myMember.isAdmin || myMember.isOwner) &&
          myMember.status == MemberStatus.active
      ? Map.of(memberEmails)
      : const {};
  @override
  Future<List<Member>> fetchMembers(String workspaceId) async => [
    myMember,
    ...otherMembers,
  ];
  /// #3858 — the Demo's dated plan changes and pauses.
  final memberTermChanges = <MemberTermChange>[];

  @override
  Future<List<MemberTermChange>> fetchMemberTermChanges(
    String workspaceId,
  ) async => List.of(memberTermChanges);

  /// #3858 — the months a standing subscription invoice froze, by member.
  final memberInvoicedMonths = <String, Set<DateTime>>{};

  @override
  Future<Map<String, Set<DateTime>>> fetchInvoicedMonths(
    String workspaceId,
  ) async => {
    for (final e in memberInvoicedMonths.entries) e.key: {...e.value},
  };

  @override
  Future<List<Member>> fetchMyMembers() async => [
    myMember,
    ...extraMyMemberships,
  ];
  @override
  Future<void> updateMemberSubscription(String memberId, int pct) async {
    if (pct < 0 || pct > 100) throw StateError('pct out of range');
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(subscriptionPct: pct);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(subscriptionPct: pct);
    }
  }

  @override
  Future<void> updateMemberOveragePolicy(
    String memberId,
    OveragePolicy policy,
  ) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(overagePolicy: policy);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(overagePolicy: policy);
    }
  }

  @override
  Future<void> setMemberReservationLimit(String memberId, int? limit) async {
    if (myMember.id == memberId) {
      throw StateError('cannot set your own reservation limit');
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(maxActiveReservations: limit);
    }
  }

  @override
  Future<void> setMemberCustomerCapacity(
    String memberId,
    String? capacity,
  ) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(customerCapacity: capacity);
    }
  }

  @override
  Future<void> setMemberEInvoiceAddress(
    String memberId, {
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
  }) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(
        einvoiceEndpointId: endpointId.trim(),
        einvoiceEndpointScheme: endpointScheme.trim().toUpperCase(),
        billingSubdivision: subdivision.trim().toUpperCase(),
      );
    }
  }

  @override
  Future<void> setMemberVatTreatment(
    String memberId,
    String treatment,
    String reason,
  ) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(
        vatTreatment: treatment,
        vatExemptionReason: reason,
      );
    }
  }

  @override
  Future<void> setMemberSimultaneousLimit(String memberId, int? limit) async {
    // #628 — the 0119 RPC mirrors 0044's governance: never for oneself.
    if (myMember.id == memberId) {
      throw StateError('cannot set your own simultaneous limit');
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(
        maxSimultaneousReservations: limit,
      );
    }
  }

  @override
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  }) async {
    levelPermissions[memberId] = allowed;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i != -1) {
      otherMembers[i] = otherMembers[i].copyWith(canReserveLevel: allowed);
    }
  }

  @override
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(isKiosk: isKiosk);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(isKiosk: isKiosk);
    }
  }

  @override
  Future<void> setInvitationTemplates(
    String workspaceId,
    Map<String, String> templates,
  ) async {
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i < 0) return;
    workspaces[i] = workspaces[i].copyWith(
      invitationTemplates: {
        for (final entry in templates.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      },
    );
  }

  @override
  Future<void> setCoOwner(String memberId, CoOwnerStatus status) async {
    // Server contract (0058): active co-owners also become admins.
    Member patch(Member m) => m.copyWith(
      coOwner: status,
      isAdmin: status == CoOwnerStatus.active || m.isAdmin,
    );
    if (myMember.id == memberId) {
      myMember = patch(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = patch(otherMembers[i]);
  }

  @override
  Future<void> activateCoOwner(String memberId) async {
    Member promote(Member m) =>
        m.copyWith(isOwner: true, isAdmin: true, coOwner: CoOwnerStatus.none);
    if (myMember.id == memberId) {
      myMember = promote(myMember);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = promote(otherMembers[i]);
  }

  @override
  Future<void> unsetMyKiosk(String workspaceId) async {
    // Server contract (0056): only an actual kiosk membership reverts.
    if (!myMember.isKiosk || myMember.workspaceId != workspaceId) {
      throw const PostgrestException(message: 'not a kiosk of this workspace');
    }
    myMember = myMember.copyWith(isKiosk: false);
  }

  @override
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  }) async {
    lastRoleChange = (workspaceId, memberId, makeAdmin);
  }

  @override
  Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) async =>
      newMemberDefaults[workspaceId] ?? const NewMemberDefaults();
  @override
  Future<void> setNewMemberDefaults(
    String workspaceId,
    NewMemberDefaults defaults,
  ) async {
    newMemberDefaults[workspaceId] = defaults;
  }

  @override
  Future<void> updateMemberStatus(String memberId, MemberStatus status) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(status: status);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = otherMembers[i].copyWith(status: status);
  }

  InvitationAnswer invitationState(String code) {
    final fixed = invitationAnswers[code];
    if (fixed != null) return fixed;
    final joined = joinedByCode[code];
    if (joined != null) {
      return InvitationAnswer(
        InvitationState.alreadyMember,
        workspaceId: joined,
        workspaceName: 'Joined Space',
        memberStatus: myMember.workspaceId == joined
            ? myMember.status
            : MemberStatus.active,
      );
    }
    final minted = mintedInvitations.where((i) => i.code == code).firstOrNull;
    if (minted != null && redeemedInvitations.contains(code)) {
      return const InvitationAnswer(InvitationState.wrongAccount);
    }
    if (minted == null && code != 'GOODCODE22') {
      return const InvitationAnswer(InvitationState.invalid);
    }
    return InvitationAnswer(
      InvitationState.valid,
      workspaceName: 'Joined Space',
      environment: 'dev',
      offeredRole: minted?.isAdmin ?? false
          ? InviteRole.admin
          : InviteRole.user,
      requiresApproval: true,
    );
  }
}
