// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invitation_answer.dart';
import 'member.dart';
import 'new_member_defaults.dart';
import 'overage_policy.dart';

/// Members, their terms and limits, invitations and joining.
///
/// A part of [WorkspaceRepository] (#2597): that interface is the sum of
/// these, so no caller changes.
abstract class MembershipRepository {
  /// The signed-in user's membership in [workspaceId], or null.
  Future<Member?> fetchMyMember(String workspaceId);

  /// member id → display name for everyone in the workspace (floor-plan
  /// occupant labels, event actor names, …).
  Future<Map<String, String>> fetchMemberNames(String workspaceId);

  /// member id → email for the members lists (#410). ADMIN surface: the
  /// server returns the empty set for non-admin callers, so plain
  /// members never see co-members' emails (contact info stays opt-in).
  Future<Map<String, String>> fetchMemberEmails(String workspaceId);

  /// All memberships of the workspace (owner management screen).
  Future<List<Member>> fetchMembers(String workspaceId);

  /// All of MY membership rows across workspaces — one per profile (#89).
  Future<List<Member>> fetchMyMembers();

  /// Owner-only (RLS-enforced): set the subscription percentage (1–100,
  /// ADR 0008) / change membership status.
  Future<void> updateMemberSubscription(String memberId, int pct);

  Future<void> updateMemberStatus(String memberId, MemberStatus status);

  /// Owner-only: set how the member is treated once they have used their
  /// whole monthly entitlement (migration 0041).
  Future<void> updateMemberOveragePolicy(String memberId, OveragePolicy policy);

  /// Admin/owner (RPC `set_member_reservation_limit`, migration 0044):
  /// cap another member's simultaneous open reservations. Null lifts the
  /// cap. The server refuses self-setting.
  Future<void> setMemberReservationLimit(String memberId, int? limit);

  /// Admin/owner (RPC `set_member_simultaneous_limit`, migration 0119):
  /// how many OVERLAPPING bookings this member may hold (#628). Null
  /// falls back to the workspace default. The server refuses
  /// self-setting, exactly like [setMemberReservationLimit].
  Future<void> setMemberSimultaneousLimit(String memberId, int? limit);

  /// #985 (RPC `set_member_vat_treatment`, migration 0182): who this
  /// member is for VAT — the wire of `VatTreatment` — and the reason an
  /// exempt buyer prints. Whoever may issue invoices.
  Future<void> setMemberVatTreatment(
    String memberId,
    String treatment,
    String reason,
  );

  /// #1916 (RPC `set_member_customer_capacity`, migration 0349): whether
  /// this member acts as a `business` or a `consumer` customer; null =
  /// not stated. Whoever may issue invoices.
  Future<void> setMemberCustomerCapacity(String memberId, String? capacity);

  /// #2358 (RPC `set_member_einvoice_address`, migration 0414): where this
  /// customer receives e-invoices (BT-49 and its EAS scheme) and the
  /// county or province of its address. Whoever may issue invoices.
  Future<void> setMemberEInvoiceAddress(
    String memberId, {
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
  });

  /// Admin/owner (RPC `set_member_level_permission`, migration 0050):
  /// grant or revoke another member's right to reserve a whole level.
  /// The server refuses self-setting.
  Future<void> setMemberLevelPermission(
    String memberId, {
    required bool allowed,
  });

  /// Owner-only (RPC `set_member_kiosk`, migration 0043): flag a member
  /// account as a wall-mounted kiosk device (or back to a regular member).
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk});

  /// Self-service escape hatch (RPC `unset_my_kiosk`, migration 0056):
  /// the signed-in kiosk account reverts ITSELF to a regular member.
  /// Flagging a member as kiosk stays owner-only.
  Future<void> unsetMyKiosk(String workspaceId);

  /// Appoints/changes/clears a co-owner (RPC `set_co_owner`, 0058) —
  /// owner-gated server-side; active co-owners may manage co-owners too.
  Future<void> setCoOwner(String memberId, CoOwnerStatus status);

  /// Promotes a co-owner to FULL owner right now (RPC
  /// `activate_co_owner`, 0058).
  Future<void> activateCoOwner(String memberId);

  /// Joins via invite code. Returns the workspace id. The granted role is
  /// derived server-side from which code matched: the workspace ID joins
  /// as a plain user; any other code must be an unredeemed, unexpired
  /// personal invitation, whose row fixes the role (0051) — a join
  /// therefore always carries a role, and never `owner`.
  Future<String> joinWorkspace(String inviteCode);

  /// #1652 (0309) — what [inviteCode] would do for the signed-in account,
  /// read without writing anything: the workspace's name, environment and
  /// offered role, or why it cannot be used.
  Future<InvitationAnswer> previewInvitation(String inviteCode);

  /// #1652 (0309) — joins through the same admission path as
  /// [joinWorkspace] and answers what happened. A repeated call answers
  /// already-member instead of joining twice.
  Future<InvitationAnswer> joinByInvitation(String inviteCode);

  /// Mints a personal, single-use invitation (0051) and returns its code.
  /// Admins may mint member invites; only owners may mint admin invites —
  /// the server enforces both, this just surfaces the exception.
  Future<String> createInvitation(
    String workspaceId, {
    required bool isAdmin,
    String firstName = '',
    String lastName = '',

    /// #887 — bound to a managed member: whoever redeems the code takes
    /// that profile over instead of joining as a new member.
    String? memberId,

    /// #1119 — whether redeeming this also makes the person a member of
    /// the PROD twin. The server refuses it when the role being invited
    /// does not hold `accessProd`: an invitation may not grant what the
    /// role matrix withholds.
    bool alsoProd = false,
  });

  /// Admin/owner (RPC `decide_member_join`, migration 0052): approves
  /// (active) or rejects (exited) a PENDING membership and settles its
  /// member_join validation event. The quorum path through
  /// respond_to_event stays available on the events feed.
  Future<void> decideMemberJoin(
    String memberId, {
    required bool approve,
    String comment = '',
    String? expectedAccount,
  });

  /// Owner-only: request a role change — promote a member to admin
  /// (make_admin true) or demote an admin to a regular member. Routed
  /// through the validation quorum (0035): returns the pending event id;
  /// the flag flips only once validators confirm.
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  });

  /// Owner-only (workspaces_update RLS): replace the per-locale custom
  /// invitation templates (0096). Empty entries are dropped.
  Future<void> setInvitationTemplates(
    String workspaceId,
    Map<String, String> templates,
  );

  /// Owner-only (workspaces_update RLS): set the invitation message
  /// template (0049) — trimmed, '' means "use the localized default".
  /// Length capped at [invitationTemplateMaxLength] by the column check.
  Future<void> setInvitationTemplate(String workspaceId, String template);

  /// #1294 — how a newly joining member starts
  /// (`billing_rules.new_member_defaults`). Read by the settings screen;
  /// applied by the server in `join_workspace` and
  /// `create_managed_member`, on insert only.
  Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId);

  /// Writes that key, preserving every other billing rule. The merge
  /// happens in the database (#1089): reading the blob, changing a key
  /// and writing it back is how two admins with the screen open each
  /// revert the other.
  Future<void> setNewMemberDefaults(
    String workspaceId,
    NewMemberDefaults defaults,
  );
}
