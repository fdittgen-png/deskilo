// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../profile/domain/personal_info.dart';
import 'managed_access.dart';

/// Managed members: an identity an admin holds on someone's behalf, and the handover.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class ManagedIdentityRepository {
  /// #887 — a member the admin runs until the person claims it (RPC
  /// `create_managed_member`, 0153): active at once, named from
  /// [identity]. Returns the member id. #914 — [access] states who may
  /// administer it; the default is every owner and admin.
  Future<String> createManagedMember(
    String workspaceId,
    PersonalInfo identity, {
    ManagedAccess access,
  });

  /// #915 — the identity behind the rule (RPC `managed_identity_of`):
  /// refused when the rule does not name the caller, and WRITTEN DOWN
  /// when it does, so the person sees who looked once they claim it.
  Future<PersonalInfo> managedIdentityOf(String memberId);

  /// #914 — states who may administer a managed profile (RPC
  /// `set_managed_access`). The workspace owner may always change a
  /// rule, so a profile can never become unadministrable.
  Future<void> setManagedAccess(String memberId, ManagedAccess access);

  /// #887 — the admin edits a managed member's identity while nobody
  /// owns it (RPC `update_managed_identity`).
  Future<void> updateManagedIdentity(String memberId, PersonalInfo identity);

  /// #887 — takes an unredeemed handover back (RPC `revoke_handover`).
  Future<void> revokeHandover(String memberId);
}
