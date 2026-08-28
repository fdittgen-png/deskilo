// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../core/badge/app_badge.dart';
import '../../core/motion/motion.dart';
import '../../core/realtime/realtime_providers.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/push/push_providers.dart';
import '../../core/storage/note_seen_store.dart';
import '../../core/time/work_hours.dart';
import '../../core/time/workspace_time.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/domain/check_in_reminders.dart';
import '../../features/reservations/presentation/widgets/space_scan.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/member_note_refs.dart';
import '../../features/workspace/providers/conversation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../router.dart';
import 'shell_bottom_bar.dart';
import '../../core/time/clock.dart';

/// App-bar events bell with the pending-confirmation badge (spec §8.1).
/// #230 moved the events feed off the bottom bar; the badge that used to
/// decorate the Events tab now decorates this bell on every tab.
class _EventsBellIcon extends ConsumerWidget {
  const _EventsBellIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #687 — pending confirmations ONLY. Unread messages moved to the
    // Messages destination, which is where tapping them leads: a bell
    // that counted them sent people to a feed to find a conversation
    // that was one tab away, and counted their OWN sent messages on the
    // way.
    final count = ref.watch(myPendingEventCountProvider).value ?? 0;
    const icon = Icon(Icons.notifications_outlined);
    // #611 — a changed count scales in briefly, so "something new needs
    // you" registers peripherally. Keyed per count: 1→2 animates too.
    return AnimatedSwitcher(
      duration: motionDuration(context, MotionTokens.quick),
      switchInCurve: MotionTokens.enter,
      switchOutCurve: MotionTokens.ease,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: count == 0
          ? const KeyedSubtree(
              key: ValueKey('events-bell-plain'), child: icon)
          : Badge.count(
              key: ValueKey('events-bell-$count'),
              count: count,
              child: icon,
            ),
    );
  }
}

/// Note ids already announced THIS SESSION — belt to the persisted
/// NOTIFIED stamp's braces: two racing provider refreshes must not
/// announce the same note twice before the stamp lands.
final Set<String> _sessionNotifiedNoteIds = <String>{};

/// Bottom-navigation shell hosting the four tab branches
/// Plan · Calendar · Members · Money (spec §13, members since #230).
/// Settings is not a tab — it is the top-right app-bar action, as in
/// Sparkilo; the events feed sits behind the app-bar bell beside it.
/// The Messages destination icon, badged only when there is something to
/// badge (#687). The count comes from the SAME query the list renders,
/// so the badge cannot disagree with the screen it points at.
Widget _messagesIcon(IconData icon, int unread) => unread > 0
    ? Badge.count(count: unread, child: Icon(icon))
    : Icon(icon);

class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(myMemberProvider).value?.actsAsOwner ?? false;

    // Fire-and-forget push start (#72); no-op while Firebase is unconfigured.
    ref.watch(pushBootstrapProvider);

    // Push-driven freshness (#413): DB changes invalidate their cached
    // providers on every device, this one included — no restarts, no
    // manual refresh.
    ref.watch(realtimeInvalidatorProvider);

    // App-icon badge (#426) + notification mirror (#432): launchers
    // like One UI ignore app-set badge numbers and count ACTIVE
    // notifications instead — so each pending confirmation is mirrored
    // as one notification (resolved ones vanish), and the explicit
    // count still serves iOS/macOS and honoring launchers.
    ref.listen(myPendingEventsProvider, (_, next) {
      final pending = next.value;
      if (pending == null) return;
      ref.read(appBadgeProvider).update(
          pending.length + (ref.read(unreadNoteCountProvider).value ?? 0));
      ref.read(notificationServiceProvider).syncPendingNotifications([
        for (final e in pending)
          (
            id: e.id,
            title: l10n?.pushPendingTitle ?? 'DesKilo',
            body: l10n?.pushPendingBody ??
                'Someone needs your confirmation.',
          ),
      ]);
    });

    // Member notes (#456/#464): every note for me that this DEVICE has
    // not yet announced pops as a local notification with sender and
    // text — INCLUDING catch-up: without the owner's Firebase setup no
    // push endpoint exists, so notes sent while the app was closed
    // must be announced on the next start. The persisted NOTIFIED
    // stamp makes each note announce exactly once per device.
    ref.listen(myNotesProvider, (previous, next) {
      final notes = next.value;
      if (notes == null || notes.isEmpty) return;
      unawaited(() async {
        // AWAIT the caches (#464): at boot the notes can land before
        // the member/name fetches — a sync read then yields a null id
        // (announcing nothing) or a nameless title.
        final myId = (await ref.read(myMemberProvider.future))?.id;
        if (myId == null) return;
        final names = await ref.read(memberNamesProvider.future);
        final store = ref.read(noteSeenStoreProvider);
        final notifiedUntil = await store.readNotified();
        DateTime? newest;
        // Oldest → newest so multiple catch-up notes read in order.
        for (final note in notes.reversed) {
          if (note.fromMemberId == myId) continue;
          if (notifiedUntil != null &&
              !note.createdAt.isAfter(notifiedUntil)) {
            continue;
          }
          if (!_sessionNotifiedNoteIds.add(note.id)) continue;
          // The names cache can lag a fresh boot — a nameless "Message
          // from" reads broken, so fall back to the app title (#460).
          final sender = names[note.fromMemberId] ?? '';
          await ref.read(notificationServiceProvider).showNow(
                title: sender.isEmpty
                    ? (l10n?.pushPendingTitle ?? 'DesKilo')
                    : (l10n?.memberNoteReceived(sender) ??
                        'Message from $sender'),
                // #523 — reference tokens read as their labels.
                body: notePlainText(note.body),
              );
          if (newest == null || note.createdAt.isAfter(newest)) {
            newest = note.createdAt;
          }
        }
        if (newest != null) await store.writeNotified(newest);
      }());
    });

    // Unread notes count on the app icon too (#464) — refresh the
    // badge when unread changes without a pending-events change.
    ref.listen(unreadNoteCountProvider, (_, next) {
      final unread = next.value;
      if (unread == null) return;
      final pending =
          ref.read(myPendingEventsProvider).value?.length ?? 0;
      ref.read(appBadgeProvider).update(pending + unread);
    });

    // Day-based booking windows anchor to the WORKSPACE clock — install
    // the active workspace's zone (re-installs on profile switch). A
    // device hours away must still book the workspace's midnights.
    WorkspaceTime.install(
      ref.watch(currentWorkspaceProvider).value?.timezone,
    );

    // The working day (#446) is ambient for the same reason as the
    // clock: the HalfDayWindows builders travel as function references.
    WorkHours.install(ref.watch(workHoursProvider).value);

    // Keep the local check-in reminders in sync with my upcoming bookings
    // (spec §4.3). Best-effort; failures never disturb the UI.
    ref.listen(myUpcomingReservationsProvider, (_, next) async {
      final upcoming = next.value;
      if (upcoming == null) return;
      final member = await ref.read(myMemberProvider.future);
      if (member == null) return;
      final targets = await ref.read(targetNamesProvider.future);
      final timeFormat = DateFormat.Hm();
      final reminders = upcomingCheckInReminders(
        reservations: upcoming,
        myMemberId: member.id,
        now: ref.read(clockProvider).now(),
        targetNames: targets,
        titleOf: (target, startsAt) =>
            l10n?.reminderTitle ?? 'Check in soon',
        bodyOf: (target, startsAt) =>
            l10n?.reminderBody(
              target,
              timeFormat.format(startsAt.toLocal()),
            ) ??
            '$target starts at ${timeFormat.format(startsAt.toLocal())}',
      );
      ref
          .read(notificationServiceProvider)
          .rescheduleCheckInReminders(reminders);
    });
    final tabTitles = [
      // #687 — the first destination is Messages now; the plan lives on
      // Réserver, which draws the same canvas.
      l10n?.messagesTitle ?? 'Messages',
      l10n?.tabCalendar ?? 'Calendar',
      l10n?.directoryTitle ?? 'Members',
      l10n?.tabMoney ?? 'Money',
      // The centre button's branch (#reserve-as-branch): not a bar
      // destination, but it owns the app-bar title while active.
      l10n?.shellReserveButton ?? 'Reserve',
    ];

    // Per-workspace feature gating (#146): the router branches stay fixed,
    // but disabled features drop their destination — so the bottom-bar
    // position and the branch index diverge and must be mapped both ways.
    // Messages (and Settings in the app bar) are core and never gated —
    // a workspace with no messaging surface has no way to reach a
    // conversation someone already sent it.
    final features = ref.watch(enabledFeaturesSyncProvider);
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final visibleBranches = [
      ShellBranch.plan,
      if (features.contains(WorkspaceFeature.calendarTab))
        ShellBranch.calendar,
      // The member directory tab is feature-gated since the hierarchy
      // pass (membersDirectory, default ON); the eventsTab feature gates
      // the app-bar bell.
      if (features.contains(WorkspaceFeature.membersDirectory))
        ShellBranch.directory,
      if (features.contains(WorkspaceFeature.moneyTab)) ShellBranch.money,
    ];
    final selectedPosition =
        visibleBranches.indexOf(navigationShell.currentIndex);

    ShellDestination destinationFor(int branch) => switch (branch) {
          ShellBranch.calendar => ShellDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: tabTitles[ShellBranch.calendar],
            ),
          ShellBranch.directory => ShellDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: tabTitles[ShellBranch.directory],
            ),
          ShellBranch.money => ShellDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: tabTitles[ShellBranch.money],
            ),
          // #687 — the messaging centre, carrying its own unread count.
          // The count comes from the SAME query the list renders, so the
          // badge cannot disagree with the screen it points at.
          // No unread, NO BADGE WIDGET — not a hidden one. An
          // always-present badge with isLabelVisible:false renders
          // nothing and still answers find.byType(Badge), which is a
          // widget in the tree lying about an empty inbox.
          _ => ShellDestination(
              icon: _messagesIcon(Icons.forum_outlined, unreadMessages),
              selectedIcon: _messagesIcon(Icons.forum, unreadMessages),
              label: tabTitles[ShellBranch.plan],
            ),
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[navigationShell.currentIndex]),
        actions: [
          // The editor sits on BOTH map surfaces (field request). Plan
          // and Réserver draw the same canvas from the same providers,
          // so an owner who spots a wrong desk while booking had to
          // leave the hub, switch tab and come back — for the same fix
          // they could make where they saw the problem.
          // #687 — Réserver is the only map surface now, so the editor
          // sits there and nowhere else.
          // Space QR scan (field request): a desk/office/level card opens
          // that space's permitted actions.
          //
          // #699 — it used to sit in the hub's control rows, where it
          // cost the width that pushed the window chips onto a third
          // line. It reads better here anyway: scanning a card is an
          // action ON the whole surface, like opening the editor beside
          // it, not a control that changes what the plan below shows.
          if (navigationShell.currentIndex == ShellBranch.reserve &&
              features.contains(WorkspaceFeature.spaceQrCodes))
            IconButton(
              key: const ValueKey('reserve-scan-button'),
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: l10n?.spaceScanTitle ?? 'Scan a space code',
              onPressed: () => scanSpace(context, ref),
            ),
          if (isOwner && navigationShell.currentIndex == ShellBranch.reserve)
            IconButton(
              key: const ValueKey('shell-editor-button'),
              icon: const Icon(Icons.design_services_outlined),
              tooltip: l10n?.editorOpenTooltip ?? 'Edit workspace',
              onPressed: () => context.push('/editor'),
            ),
          // Events bell (#230): pushes the feed that used to be a tab,
          // carrying its pending-count badge. Hidden entirely when the
          // workspace gated the events feature off.
          if (features.contains(WorkspaceFeature.eventsTab))
            IconButton(
              icon: const _EventsBellIcon(),
              tooltip: l10n?.tabEvents ?? 'Events',
              onPressed: () => context.push('/events'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n?.settingsTitle ?? 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      // #611 — the tab switch fades the incoming branch in. The
      // FadeIndexedStack pattern: the shell's IndexedStack (and with it
      // the #111 per-tab keep-alive state) stays untouched; only an
      // opacity layer above it animates, keyed by the active branch.
      body: FadeInOnChange(
        changeKey: navigationShell.currentIndex,
        child: navigationShell,
      ),
      // The bar needs at least two destinations to flank the notch. Since
      // #230 the ungated Members tab guarantees Plan + Members even with
      // everything gated off; the guard stays as a safety net should a
      // branch ever become gated again.
      bottomNavigationBar: visibleBranches.length < 2
          ? null
          : ShellBottomBar(
              // -1 when no side tab matches the active branch — on the
              // Reserve hub (the centre button carries the indication
              // instead) and for one redirect frame of a gated branch.
              // Never coerce to 0: that painted Plan as selected while
              // the hub was the loaded form.
              selectedIndex: selectedPosition,
              reserveSelected:
                  navigationShell.currentIndex == ShellBranch.reserve,
              onDestinationSelected: (position) => navigationShell.goBranch(
                visibleBranches[position],
                initialLocation:
                    visibleBranches[position] == navigationShell.currentIndex,
              ),
              destinations: [
                for (final branch in visibleBranches) destinationFor(branch),
              ],
              reserveLabel: l10n?.shellReserveButton ?? 'Reserve',
              // A branch switch, not a push — the bar (and this button)
              // stay visible and functional on the hub.
              onReservePressed: () => navigationShell.goBranch(
                ShellBranch.reserve,
                initialLocation:
                    navigationShell.currentIndex == ShellBranch.reserve,
              ),
            ),
    );
  }
}
