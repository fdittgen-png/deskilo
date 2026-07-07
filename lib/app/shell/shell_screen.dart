// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';

/// Bottom-navigation shell hosting the four tab branches
/// Plan · Calendar · Events · Money (spec §13). Settings is not a tab —
/// it is the top-right app-bar action, as in Sparkilo.
class ShellScreen extends StatelessWidget {
  const ShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
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
