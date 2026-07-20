// SPDX-License-Identifier: MIT
import 'booking_granularity.dart';
import 'closure_day.dart';
import 'member.dart';
import 'member_badge.dart';
import 'overage_policy.dart';
import 'payment_instructions.dart';
import 'workspace.dart';

/// Pure-Dart workspace boundary. Supabase impl in data/, fake in tests.
abstract class WorkspaceRepository {
  /// Workspaces the signed-in user is a non-exited member of.
  Future<List<Workspace>> fetchMyWorkspaces();

  /// Creates a workspace; the caller becomes its owner. Returns the id.
  Future<String> createWorkspace({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
  });

  /// Joins via invite code. Returns the workspace id. The granted role is
  /// derived server-side from which code matched: the workspace ID joins
  /// as a plain user, the admin invite code as an admin (0030) — a join
  /// therefore always carries a role, and never `owner`.
  Future<String> joinWorkspace(String inviteCode);

  /// The workspace's admin invite code, or null when the caller is not
  /// its owner (owner-only RLS on workspace_admin_invites, 0030).
  Future<String?> adminInviteCode(String workspaceId);

  /// Owner-only (workspaces_update RLS): change the workspace locale —
  /// country, currency and time zone (#153). Currency defaults from the
  /// country in the UI but any ISO 4217 override is persisted verbatim.
  Future<void> updateWorkspaceLocale(
    String workspaceId, {
    required String countryCode,
    required String currencyCode,
    required String timezone,
  });

  /// Owner-only (workspaces_update RLS): replace the workspace's payment
  /// instructions wholesale (#155). Shown to members on unpaid
  /// statements.
  Future<void> setPaymentInstructions(
    String workspaceId,
    PaymentInstructions instructions,
  );

  /// Owner-only (workspaces_update RLS): set the community's WhatsApp
  /// group invite link (#231) — trimmed, '' clears it. Must satisfy
  /// [WhatsappGroupRules.isValid]; the 0029 column check re-validates
  /// the chat.whatsapp.com prefix server-side.
  Future<void> setWhatsappGroup(String workspaceId, String link);

  /// The signed-in user's membership in [workspaceId], or null.
  Future<Member?> fetchMyMember(String workspaceId);

  /// member id → display name for everyone in the workspace (floor-plan
  /// occupant labels, event actor names, …).
  Future<Map<String, String>> fetchMemberNames(String workspaceId);

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
  Future<void> updateMemberOveragePolicy(
    String memberId,
    OveragePolicy policy,
  );

  /// Admin/owner (RPC `set_member_reservation_limit`, migration 0044):
  /// cap another member's simultaneous open reservations. Null lifts the
  /// cap. The server refuses self-setting.
  Future<void> setMemberReservationLimit(String memberId, int? limit);

  /// Owner-only (RPC `set_member_kiosk`, migration 0043): flag a member
  /// account as a wall-mounted kiosk device (or back to a regular member).
  Future<void> setMemberKiosk(String memberId, {required bool isKiosk});

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

  /// Owner-only: request a role change — promote a member to admin
  /// (make_admin true) or demote an admin to a regular member. Routed
  /// through the validation quorum (0035): returns the pending event id;
  /// the flag flips only once validators confirm.
  Future<void> requestRoleChange(
    String workspaceId, {
    required String memberId,
    required bool makeAdmin,
  });

  /// Owner-only: replace the workspace ID (= invite code, shown in the QR)
  /// with a memorable alphanumeric one (4–20 A-Z/0-9, unique). Returns the
  /// normalized code.
  Future<String> setWorkspaceCode(String workspaceId, String code);

  /// Owner-only (RLS-enforced): replace the workspace's feature_flags
  /// jsonb wholesale (#146). Keys are WorkspaceFeature enum names.
  Future<void> setFeatureFlags(String workspaceId, Map<String, bool> flags);

  /// ISO weekdays (1=Mon..7=Sun) the workspace is open on (#127); read
  /// from booking_rules, defaults to Mon–Fri when the key is absent.
  Future<List<int>> fetchOpenWeekdays(String workspaceId);

  /// Owner-only (RLS-enforced): persist the open weekdays inside
  /// booking_rules without clobbering its other keys.
  Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays);

  /// The workspace's booking-granularity rule (#200); read from
  /// booking_rules, [BookingGranularity.flexible] when absent.
  Future<BookingGranularity> fetchBookingGranularity(String workspaceId);

  /// Owner-only (RLS-enforced): persist the granularity inside
  /// booking_rules without clobbering its other keys.
  Future<void> setBookingGranularity(
    String workspaceId,
    BookingGranularity granularity,
  );

  /// One-off closure days of the workspace, ordered by day (#127).
  Future<List<ClosureDay>> fetchClosureDays(String workspaceId);

  /// Owner-only: add a closure day. Returns the created row.
  Future<ClosureDay> addClosureDay(
    String workspaceId,
    DateTime day,
    String reason,
  );

  /// Owner-only: remove a closure day.
  Future<void> removeClosureDay(String closureDayId);

  /// Owner-only: set the desk fill opacity percentage (0040), clamped
  /// 20..100 server-side. Lower = more translucent desks.
  Future<void> setDeskOpacity(String workspaceId, int opacity);

  /// Owner-only, irreversible (0039): wipe all transactions (reservations,
  /// events, ledger, quota extensions) and the entire floor plan (levels,
  /// offices, desks, seats, plan images) while keeping the workspace
  /// configuration and its members. The client gates this behind a typed
  /// confirmation.
  Future<void> resetWorkspace(String workspaceId);
}
