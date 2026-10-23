// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — what the shell does for the whole session besides drawing: it
// installs the ambient workspace facts (zone, hours, words, currency),
// keeps the app-icon badge and the mirrored notifications in step, announces
// member notes and schedules check-in reminders. It used to be the first
// 170 lines of ShellScreen.build; each concern is a function of its own,
// called in the same order, and everything it created lives in the
// ShellSession (shell_session.dart).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/badge/app_badge.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/i18n/workspace_currency.dart';
import '../../core/l10n/lexicon.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/notifications/reminder_sync.dart';
import '../../core/push/push_providers.dart';
import '../../core/realtime/realtime_providers.dart';
import '../../core/settings/booking_windows.dart';
import '../../core/storage/note_seen_store.dart';
import '../../core/time/clock.dart';
import '../../core/time/work_hours.dart';
import '../../core/time/workspace_time.dart';
import '../../core/trace/trace_logger.dart';
import '../../core/ui/app_snack.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/mcp/presentation/mcp_operation_labels.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/domain/check_in_reminders.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/member_note.dart';
import '../../features/workspace/domain/member_note_refs.dart';
import '../../features/workspace/providers/conversation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../webmcp_confirmation_sheet.dart';
import '../webmcp_confirmations.dart';
import '../webmcp_wiring.dart';
import 'shell_session.dart';

/// Starts every shell-wide effect. Called from the shell's build; the
/// watches and listeners belong to that build's element, as before.
void watchShellEffects(WidgetRef ref, AppLocalizations l10n) {
  final session = ref.watch(shellSessionProvider);
  _watchAmbientProviders(ref);
  _mirrorPendingEvents(ref, l10n);
  _announceMemberNotes(ref, l10n, session);
  _syncUnreadBadge(ref);
  _installWorkspaceAmbients(ref);
  _scheduleCheckInReminders(ref, l10n);
  _announceWebMcpActions(ref, l10n);
  _askWebMcpConfirmations(ref);
}

/// #2504 — an assistant's request that needs the person: the sheet opens,
/// and their answer (or none, if they close it) goes back to the page.
void _askWebMcpConfirmations(WidgetRef ref) {
  ref.listen(webMcpConfirmationsProvider, (_, request) async {
    if (request == null || !ref.context.mounted) return;
    final workspace = ref.read(currentWorkspaceProvider).value?.name ?? '';
    final accept = await showWebMcpConfirmationSheet(
      ref.context,
      request,
      workspaceName: workspace,
    );
    if (accept == null) return;
    ref.read(webMcpConfirmationsProvider.notifier).decide(request.key, accept: accept);
  });
}

/// #2504 — an assistant in this browser acted through the page: say what,
/// unobtrusively, so the page and the agent stay in step.
void _announceWebMcpActions(WidgetRef ref, AppLocalizations l10n) {
  ref.listen(webMcpActivityProvider, (_, operation) {
    if (operation == null || !ref.context.mounted) return;
    AppSnack.info(
      ref.context,
      l10n.webMcpActed(mcpOperationLabel(l10n, operation)),
    );
  });
}

/// #821 — the conversations I muted; empty when the list cannot be
/// read, so a failing fetch silences nothing by accident.
Future<Set<String>> _mutedConversationIds(WidgetRef ref) async {
  try {
    final list = await ref.read(conversationsProvider.future);
    return {
      for (final c in list)
        if (c.muted) c.id,
    };
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'inbox',
      'muted conversations unavailable',
      error: e,
      stackTrace: st,
    );
    return const {};
  }
}

void _watchAmbientProviders(WidgetRef ref) {
  // #711 — resolve the member's format locale, clock and zone for
  // every screen under the shell. Watching it here is what sets
  // Intl.defaultLocale (#701) and WorkspaceTime.displayMode; nothing
  // below has to know.
  ref
    ..watch(appFormatProvider)
    // Fire-and-forget push start (#72); no-op while Firebase is unconfigured.
    ..watch(pushBootstrapProvider)
    // Push-driven freshness (#413): DB changes invalidate their cached
    // providers on every device, this one included — no restarts, no
    // manual refresh.
    ..watch(realtimeInvalidatorProvider(RealtimeTarget.workspace))
    ..watch(realtimeInvalidatorProvider(RealtimeTarget.account))
    // #2504 — the page's tools for an in-browser assistant; it offers
    // nothing unless every condition holds (web, feature, device switch).
    ..watch(webMcpRegistryProvider);
}

void _mirrorPendingEvents(WidgetRef ref, AppLocalizations l10n) {
  // App-icon badge (#426) + notification mirror (#432): launchers
  // like One UI ignore app-set badge numbers and count ACTIVE
  // notifications instead — so each pending confirmation is mirrored
  // as one notification (resolved ones vanish), and the explicit
  // count still serves iOS/macOS and honoring launchers.
  ref.listen(myPendingEventsProvider, (_, next) {
    final pending = next.value;
    if (pending == null) return;
    unawaited(
      ref
          .read(appBadgeProvider)
          .update(
            pending.length + (ref.read(unreadNoteCountProvider).value ?? 0),
          ),
    );
    unawaited(
      ref.read(notificationServiceProvider).syncPendingNotifications([
        for (final e in pending)
          (id: e.id, title: l10n.pushPendingTitle, body: l10n.pushPendingBody),
      ]),
    );
  });
}

void _announceMemberNotes(
  WidgetRef ref,
  AppLocalizations l10n,
  ShellSession session,
) {
  // Member notes (#456/#464): every note for me that this DEVICE has
  // not yet announced pops as a local notification with sender and
  // text — INCLUDING catch-up: without the owner's Firebase setup no
  // push endpoint exists, so notes sent while the app was closed
  // must be announced on the next start. The persisted NOTIFIED
  // stamp makes each note announce exactly once per device.
  ref.listen(myNotesProvider, (previous, next) {
    final notes = next.value;
    if (notes == null || notes.isEmpty) return;
    unawaited(_announceNotes(ref, l10n, session, notes));
  });
}

Future<void> _announceNotes(
  WidgetRef ref,
  AppLocalizations l10n,
  ShellSession session,
  List<MemberNote> notes,
) async {
  // AWAIT the caches (#464): at boot the notes can land before
  // the member/name fetches — a sync read then yields a null id
  // (announcing nothing) or a nameless title.
  try {
    final myId = (await ref.read(myMemberProvider.future))?.id;
    if (myId == null) return;
    final names = await ref.read(memberNamesProvider.future);
    final store = ref.read(noteSeenStoreProvider);
    final notifiedUntil = await store.readNotified();
    // #821 — a MUTED conversation is announced by nobody: its
    // notes still count on the row and the badge, they just stay
    // quiet. The stamp still advances past them, so unmuting later
    // never replays what was muted.
    final muted = await _mutedConversationIds(ref);
    DateTime? newest;
    // Oldest → newest so multiple catch-up notes read in order.
    for (final note in notes.reversed) {
      if (note.fromMemberId == myId) continue;
      if (notifiedUntil != null && !note.createdAt.isAfter(notifiedUntil)) {
        continue;
      }
      if (!session.notifiedNoteIds.add(note.id)) continue;
      if (!muted.contains(note.conversationId)) {
        await _announce(ref, l10n, note, names);
      }
      newest = _later(newest, note.createdAt);
    }
    if (newest != null) await store.writeNotified(newest);
  } on Object catch (e, st) {
    // A missed local announcement is not worth a crash; the note
    // is still in the inbox and on the badge.
    TraceLogger.instance.warn(
      'inbox',
      'note announcement failed',
      error: e,
      stackTrace: st,
    );
  }
}

Future<void> _announce(
  WidgetRef ref,
  AppLocalizations l10n,
  MemberNote note,
  Map<String, String> names,
) {
  // The names cache can lag a fresh boot — a nameless "Message
  // from" reads broken, so fall back to the app title (#460).
  final sender = names[note.fromMemberId] ?? '';
  return ref
      .read(notificationServiceProvider)
      .showNow(
        title: sender.isEmpty
            ? l10n.pushPendingTitle
            : l10n.memberNoteReceived(sender),
        // #523 — reference tokens read as their labels.
        body: notePlainText(note.body),
      );
}

DateTime _later(DateTime? current, DateTime candidate) =>
    current == null || candidate.isAfter(current) ? candidate : current;

void _syncUnreadBadge(WidgetRef ref) {
  // Unread notes count on the app icon too (#464) — refresh the
  // badge when unread changes without a pending-events change.
  ref.listen(unreadNoteCountProvider, (_, next) {
    final unread = next.value;
    if (unread == null) return;
    final pending = ref.read(myPendingEventsProvider).value?.length ?? 0;
    unawaited(ref.read(appBadgeProvider).update(pending + unread));
  });
}

void _installWorkspaceAmbients(WidgetRef ref) {
  // Day-based booking windows anchor to the WORKSPACE clock — install
  // the active workspace's zone (re-installs on profile switch). A
  // device hours away must still book the workspace's midnights.
  // #2561 L4 — the legacy adapter is fed from the calendar the selected
  // workspace's context captured: while W-B is being captured, W-A's zone
  // and hours are not left standing for it.
  final calendar = ref.watch(readyWorkspaceContextProvider)?.calendar;
  WorkspaceTime.install(calendar?.timezone);

  // The working day (#446) is ambient for the same reason as the
  // clock: the HalfDayWindows builders travel as function references.
  // Its provider stays watched: the booking gate reads it synchronously.
  ref.watch(workHoursProvider);
  WorkHours.install(calendar?.workHours);

  // #1277 — and the workspace's own words, ambient for the same
  // reason: the legend, the shell destinations and the booking sheet
  // all render deep inside widgets that were never handed a `ref`.
  Lexicon.install(ref.watch(lexiconProvider).value);

  // #1077 — and the currency's GRAIN, for the same reason again: the
  // major-unit editor helpers are called from three dozen forms, and a
  // yen has no minor unit at all.
  WorkspaceCurrency.install(
    ref.watch(currentWorkspaceProvider).value?.currencyCode,
  );
}

void _scheduleCheckInReminders(WidgetRef ref, AppLocalizations l10n) {
  // Keep the local check-in reminders in sync with my upcoming bookings
  // (spec §4.3). Best-effort; failures never disturb the UI — but they
  // are traced rather than swallowed (#1094), and the whole body is
  // guarded because the two provider reads can fail too.
  ref.listen(myUpcomingReservationsProvider, (_, next) async {
    final upcoming = next.value;
    if (upcoming == null) return;
    try {
      final member = await ref.read(myMemberProvider.future);
      if (member == null) return;
      final targets = await ref.read(targetNamesProvider.future);
      final timeFormat = DateFormat.Hm();
      final reminders = upcomingCheckInReminders(
        reservations: upcoming,
        myMemberId: member.id,
        now: ref.read(clockProvider).now(),
        targetNames: targets,
        lookahead: ref.read(bookingWindowsProvider).reminderLookahead,
        before: ref.read(bookingWindowsProvider).reminderLead,
        titleOf: (target, startsAt) => l10n.reminderTitle,
        // #1082 — the reminder names the hour the SPACE opens the
        // booking, which is what the member read when they booked it
        // and what the plan shows. `toLocal()` is the device's clock,
        // and #711 made the workspace's the default everywhere else.
        bodyOf: (target, startsAt) {
          final at = timeFormat.format(WorkspaceTime.wall(startsAt));
          return l10n.reminderBody(target, at);
        },
      );
      await scheduleCheckInReminders(
        ref.read(notificationServiceProvider),
        reminders,
      );
    } on Object catch (e, st) {
      // The two provider reads and the reminder build. The schedule
      // itself traces its own failure and never throws.
      TraceLogger.instance.warn(
        'notifications',
        'check-in reminders: could not read who I am or what I booked',
        error: e,
        stackTrace: st,
      );
    }
  });
}
