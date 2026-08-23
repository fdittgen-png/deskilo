// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/active_workspace_store.dart';
import '../../../core/storage/note_seen_store.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/time/work_hours.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/supabase_workspace_repository.dart';
import '../domain/booking_granularity.dart';
import '../domain/booking_policies.dart';
import '../domain/closure_day.dart';
import '../domain/member.dart';
import '../domain/member_note.dart';
import '../domain/workspace.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_permission.dart';
import '../domain/workspace_repository.dart';
import '../domain/workspace_document.dart';

part 'workspace_providers.g.dart';

@Riverpod(keepAlive: true)
WorkspaceRepository workspaceRepository(Ref ref) =>
    SupabaseWorkspaceRepository(Supabase.instance.client);

@Riverpod(keepAlive: true)
Future<List<Workspace>> myWorkspaces(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMyWorkspaces();
}

/// The persisted active-profile choice (#89). At START-UP the user's
/// DEFAULT profile wins when one is checked (#322); in-session switches
/// still take effect immediately and last until the next start. Falls
/// back to the first workspace when nothing matches.
@Riverpod(keepAlive: true)
class ActiveWorkspaceId extends _$ActiveWorkspaceId {
  @override
  Future<String?> build() async {
    // #458: the default is the SERVER-FIRST user choice, so a fresh
    // install lands on the default profile immediately.
    final defaultId = await ref.watch(defaultWorkspaceIdProvider.future);
    if (defaultId != null) return defaultId;
    return ref.watch(activeWorkspaceStoreProvider).read();
  }

  Future<void> select(String workspaceId) async {
    await ref.read(activeWorkspaceStoreProvider).write(workspaceId);
    state = AsyncData(workspaceId);
  }
}

/// The user-checked default profile (#322); null = none. Radio
/// semantics: checking one replaces the previous; re-checking the
/// current default clears it.
///
/// SERVER-FIRST since #458: the choice lives on the profile row, so it
/// survives reinstalls and follows the user across platforms. The
/// local store is demoted to an offline cache, written through on
/// every successful read and toggle.
@Riverpod(keepAlive: true)
class DefaultWorkspaceId extends _$DefaultWorkspaceId {
  @override
  Future<String?> build() async {
    final signedIn = ref.watch(authStateProvider).value != null;
    if (!signedIn) return ref.watch(defaultWorkspaceStoreProvider).read();
    try {
      final server = await ref
          .watch(workspaceRepositoryProvider)
          .fetchDefaultWorkspaceId();
      await ref.read(defaultWorkspaceStoreProvider).write(server);
      return server;
    } catch (e, st) {
      // Offline: the cached choice keeps working.
      TraceLogger.instance.warn(
          'workspace', 'default-workspace fetch failed — using cache',
          error: e, stackTrace: st);
      return ref.watch(defaultWorkspaceStoreProvider).read();
    }
  }

  Future<void> toggle(String workspaceId) async {
    final next = state.value == workspaceId ? null : workspaceId;
    await ref
        .read(workspaceRepositoryProvider)
        .setDefaultWorkspaceId(next);
    await ref.read(defaultWorkspaceStoreProvider).write(next);
    state = AsyncData(next);
  }
}

/// The active workspace (profile).
@Riverpod(keepAlive: true)
Future<Workspace?> currentWorkspace(Ref ref) async {
  final workspaces = await ref.watch(myWorkspacesProvider.future);
  if (workspaces.isEmpty) return null;
  final chosenId = await ref.watch(activeWorkspaceIdProvider.future);
  return workspaces.where((w) => w.id == chosenId).firstOrNull ??
      workspaces.first;
}

/// All memberships of the active workspace (owner management + event
/// decider computation, #107).
@riverpod
Future<List<Member>> workspaceMembers(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMembers(workspace.id);
}

/// All my membership rows across workspaces — one per profile (#89).
@Riverpod(keepAlive: true)
Future<List<Member>> myMemberships(Ref ref) async {
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMyMembers();
}

/// ISO weekdays (1=Mon..7=Sun) the active workspace is open on (#127).
/// The document library (#500) — RLS trims rows to the caller's role.
@riverpod
Future<List<WorkspaceDocument>> workspaceDocuments(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.read(workspaceRepositoryProvider).fetchDocuments(workspace.id);
}

@riverpod
Future<List<int>> openWeekdays(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [1, 2, 3, 4, 5];
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchOpenWeekdays(workspace.id);
}

/// Booking-granularity rule of the active workspace (#200); flexible
/// while no workspace is selected or the key is absent.
@riverpod
Future<BookingGranularity> bookingGranularity(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return BookingGranularity.flexible;
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchBookingGranularity(workspace.id);
}

/// The #600 booking-policy switches of the active workspace; all OFF
/// while no workspace is selected or the keys are absent.
@riverpod
Future<BookingPolicies> bookingPolicies(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const BookingPolicies();
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchBookingPolicies(workspace.id);
}

/// Working day of the active workspace (#446); [WorkHours.defaults]
/// while no workspace is selected or the keys are absent.
@riverpod
Future<WorkHours> workHours(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return WorkHours.defaults;
  return ref.watch(workspaceRepositoryProvider).fetchWorkHours(workspace.id);
}

/// Notes visible to me in the active workspace (#456), newest first —
/// the shell listens and surfaces arrivals as local notifications.
@Riverpod(keepAlive: true)
Future<List<MemberNote>> myNotes(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(workspaceRepositoryProvider).fetchMyNotes(workspace.id);
}

/// Whether the WhatsApp message mirror (0106) can actually deliver —
/// probes the send-whatsapp function's config. keepAlive: the answer
/// only changes when the owner sets the secrets.
@Riverpod(keepAlive: true)
Future<bool> whatsappMirrorConfigured(Ref ref) async {
  // #552 — per-workspace: the owner's in-app credentials count, not
  // just the operator env secrets.
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchWhatsappMirrorConfigured(workspaceId: workspace?.id);
}

/// The ids of my UNREAD received notes (#539): a direct note is unread
/// until its read receipt lands (0105 — stamped when its CONVERSATION
/// opens, 0108); a broadcast has no per-reader server state, so it
/// counts until the Events screen has been opened (the device stamp).
/// Rows bold on it, the bell counts it, the Unread filter shows it.
@Riverpod(keepAlive: true)
Future<Set<String>> unreadNoteIds(Ref ref) async {
  final me = await ref.watch(myMemberProvider.future);
  final notes = await ref.watch(myNotesProvider.future);
  final seen = await ref.watch(noteSeenStoreProvider).readSeen();
  return {
    for (final n in notes)
      if (n.fromMemberId != me?.id &&
          (n.isBroadcast
              ? (seen == null || n.createdAt.isAfter(seen))
              : n.readAt == null))
        n.id,
  };
}

/// Unread member notes (#464, reworked #539): the bell and the
/// app-icon badge count [unreadNoteIds]. Direct notes clear when their
/// conversation is opened; broadcasts when the Events screen is.
@Riverpod(keepAlive: true)
class UnreadNoteCount extends _$UnreadNoteCount {
  @override
  Future<int> build() async =>
      (await ref.watch(unreadNoteIdsProvider.future)).length;

  /// The Events screen was opened — BROADCASTS count as read (they
  /// have no per-reader server state); direct notes stay visibly
  /// unread until their conversation opens (#539).
  Future<void> markAllSeen() async {
    final notes = await ref.read(myNotesProvider.future);
    if (notes.isEmpty) return;
    // Newest first (repository order) — the first entry is the stamp.
    await ref.read(noteSeenStoreProvider).writeSeen(notes.first.createdAt);
    ref
      ..invalidate(unreadNoteIdsProvider)
      ..invalidateSelf();
  }

  /// A conversation was opened: read receipts for THAT exchange only
  /// (0108) — the sender's grey check turns blue, the rows un-bold.
  /// Best-effort — reading messages must never fail on a network blip.
  Future<void> markConversationRead(String fromMemberId) async {
    final me = await ref.read(myMemberProvider.future);
    final workspace = await ref.read(currentWorkspaceProvider.future);
    final notes = await ref.read(myNotesProvider.future);
    final unread = workspace != null &&
        notes.any((n) =>
            n.fromMemberId == fromMemberId &&
            n.toMemberId == me?.id &&
            n.readAt == null);
    if (!unread) return;
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .markMyNotesRead(workspace.id, fromMemberId: fromMemberId);
    } catch (e, st) {
      TraceLogger.instance.error('workspace', 'mark conversation read failed',
          error: e, stackTrace: st);
      return;
    }
    ref
      ..invalidate(myNotesProvider)
      ..invalidate(unreadNoteIdsProvider)
      ..invalidateSelf();
  }
}

/// One-off closure days of the active workspace, ordered by day (#127).
@riverpod
Future<List<ClosureDay>> closureDays(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchClosureDays(workspace.id);
}

/// Features enabled for the active workspace (#146). Deriving from
/// [currentWorkspace] is what makes flags "apply on connect": switching
/// profiles (#89) or refetching workspaces recomputes the set with the
/// new workspace's flags — no extra plumbing. No workspace = defaults.
@Riverpod(keepAlive: true)
Future<Set<WorkspaceFeature>> enabledFeatures(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  // Hierarchy applied here: gates all over the app see the EFFECTIVE
  // set, so switching a parent off takes its whole subtree with it.
  return effectiveFeatures(
    resolveEnabledFeatures(workspace?.featureFlags ?? const {}),
  );
}

/// Sync convenience over [enabledFeatures] for build methods and router
/// redirects. While the workspace is still loading it falls back to ALL
/// registry defaults (everything ON) so the shell never flashes a
/// reduced tab bar.
@Riverpod(keepAlive: true)
Set<WorkspaceFeature> enabledFeaturesSync(Ref ref) =>
    ref.watch(enabledFeaturesProvider).value ??
    effectiveFeatures(resolveEnabledFeatures(const {}));

/// #513 — MY effective permissions under the workspace's role matrix.
/// The one client-side gate: screens ask for a permission, never for a
/// role flag. Falls back to {} while member/workspace load.
@Riverpod(keepAlive: true)
Set<WorkspacePermission> myPermissions(Ref ref) => effectivePermissions(
      ref.watch(myMemberProvider).value,
      ref.watch(currentWorkspaceProvider).value,
    );

/// Workspace-wide developer mode (#419, 0081): admin/owner-set, applies
/// to EVERY member — gates the e-invoice test environments and the
/// Developer screen. Realtime (0080) pushes a flip to all devices live.
@Riverpod(keepAlive: true)
Future<bool> devMode(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  return workspace?.devMode ?? false;
}

/// member id → email of the active workspace's members (#410). ADMIN
/// surface: short-circuits to {} for viewers who cannot administer (no
/// wasted RPC) — and the server enforces the same gate regardless.
@riverpod
Future<Map<String, String>> memberEmails(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  final me = await ref.watch(myMemberProvider.future);
  if (!(me?.canAdminister ?? false)) return const {};
  return ref
      .watch(workspaceRepositoryProvider)
      .fetchMemberEmails(workspace.id);
}

/// The signed-in user's membership (roles!) in the active workspace.
@Riverpod(keepAlive: true)
Future<Member?> myMember(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  return ref.watch(workspaceRepositoryProvider).fetchMyMember(workspace.id);
}
