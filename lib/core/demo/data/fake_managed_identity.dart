// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the in-memory half of ManagedIdentity: moved verbatim out of the part
// files; the state it reads is `FakeWorkspaceState`.
import 'dart:async';

import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/workspace/domain/managed_access.dart';
import 'package:deskilo/features/workspace/domain/managed_identity_repository.dart';
import 'package:deskilo/features/workspace/domain/member.dart';

import 'fake_workspace_state.dart';

mixin FakeManagedIdentity on FakeWorkspaceState
    implements ManagedIdentityRepository {
  @override
  Future<String> createManagedMember(
    String workspaceId,
    PersonalInfo identity, {
    ManagedAccess access = ManagedAccess.unnarrowed,
  }) async {
    final id = 'managed-${nextManagedId++}';
    otherMembers.add(
      Member(
        id: id,
        workspaceId: workspaceId,
        userId: '',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        // #915 — the row carries the PUBLIC half only, as the server does.
        managedIdentity: PersonalInfo(
          courtesy: identity.courtesy,
          firstName: identity.firstName.trim(),
          lastName: identity.lastName.trim(),
          company: identity.company.trim(),
          countryCode: identity.countryCode.trim().toUpperCase(),
        ),
        managedName: identity.normalized().fullName,
        managedAccess: access.toJson(),
      ),
    );
    managedIdentities[id] = identity.normalized();
    return id;
  }

  @override
  Future<PersonalInfo> managedIdentityOf(String memberId) async =>
      managedIdentities[memberId] ?? PersonalInfo.empty;
  @override
  Future<void> setManagedAccess(String memberId, ManagedAccess access) async {
    lastManagedAccess = access;
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) {
      otherMembers[i] = otherMembers[i].copyWith(
        managedAccess: access.toJson(),
      );
    }
  }

  @override
  Future<void> updateManagedIdentity(
    String memberId,
    PersonalInfo identity,
  ) async {
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i < 0) throw StateError('member not found');
    otherMembers[i] = otherMembers[i].copyWith(
      managedIdentity: identity.normalized(),
    );
  }

  @override
  Future<void> revokeHandover(String memberId) async {
    revokedHandovers.add(memberId);
    mintedInvitations.removeWhere((i) => i.memberId == memberId);
  }
}
