// SPDX-License-Identifier: MIT
import 'booking_granularity.dart';
import 'closure_day.dart';
import 'member.dart';
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

  /// Joins via invite code. Returns the workspace id.
  Future<String> joinWorkspace(String inviteCode);

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
}
