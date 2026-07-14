// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../core/notifications/notification_providers.dart';
import '../../core/push/push_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/domain/check_in_reminders.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../router.dart';
import 'shell_bottom_bar.dart';

/// App-bar events bell with the pending-confirmation badge (spec §8.1).
/// #230 moved the events feed off the bottom bar; the badge that used to
/// decorate the Events tab now decorates this bell on every tab.
class _EventsBellIcon extends ConsumerWidget {
  const _EventsBellIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(myPendingEventCountProvider).value ?? 0;
    const icon = Icon(Icons.notifications_outlined);
    if (count == 0) return icon;
    return Badge.count(count: count, child: icon);
  }
}

/// Bottom-navigation shell hosting the four tab branches
/// Plan · Calendar · Members · Money (spec §13, members since #230).
/// Settings is not a tab — it is the top-right app-bar action, as in
/// Sparkilo; the events feed sits behind the app-bar bell beside it.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(myMemberProvider).value?.isOwner ?? false;

    // Fire-and-forget UnifiedPush start (#72); no-op without distributor.
    ref.watch(pushBootstrapProvider);

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
        now: DateTime.now(),
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
      l10n?.tabPlan ?? 'Plan',
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
    // Plan (and Settings in the app bar) are core and never gated.
    final features = ref.watch(enabledFeaturesSyncProvider);
    final visibleBranches = [
      ShellBranch.plan,
      if (features.contains(WorkspaceFeature.calendarTab))
        ShellBranch.calendar,
      // The member directory (#230) is core like Plan — never gated. The
      // eventsTab feature now gates the app-bar bell instead.
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
          _ => ShellDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: tabTitles[ShellBranch.plan],
            ),
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[navigationShell.currentIndex]),
        actions: [
          if (isOwner && navigationShell.currentIndex == ShellBranch.plan)
            IconButton(
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
      body: navigationShell,
      // The bar needs at least two destinations to flank the notch. Since
      // #230 the ungated Members tab guarantees Plan + Members even with
      // everything gated off; the guard stays as a safety net should a
      // branch ever become gated again.
      bottomNavigationBar: visibleBranches.length < 2
          ? null
          : ShellBottomBar(
              // While the router redirect moves a disabled branch back to
              // /plan the current branch may not be visible for one frame.
              selectedIndex: selectedPosition < 0 ? 0 : selectedPosition,
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
