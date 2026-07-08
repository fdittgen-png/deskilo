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
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import '../router.dart';

/// Events tab icon with the pending-confirmation badge (spec §8.1).
class _EventsIcon extends ConsumerWidget {
  const _EventsIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(myPendingEventCountProvider).value ?? 0;
    final icon = Icon(
      selected ? Icons.notifications : Icons.notifications_outlined,
    );
    if (count == 0) return icon;
    return Badge.count(count: count, child: icon);
  }
}

/// Bottom-navigation shell hosting the four tab branches
/// Plan · Calendar · Events · Money (spec §13). Settings is not a tab —
/// it is the top-right app-bar action, as in Sparkilo.
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
      l10n?.tabEvents ?? 'Events',
      l10n?.tabMoney ?? 'Money',
    ];

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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n?.settingsTitle ?? 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: tabTitles[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: tabTitles[1],
          ),
          NavigationDestination(
            icon: const _EventsIcon(selected: false),
            selectedIcon: const _EventsIcon(selected: true),
            label: tabTitles[2],
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: tabTitles[3],
          ),
        ],
      ),
    );
  }
}
