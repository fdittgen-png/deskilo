// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the Me layer: the person's own home, owned by nobody else.
//
// Four tabs, reachable with zero workspaces: Home (my spaces), Discover,
// Messages and Me. The layer wears DesKilo's own ink-blue and never a
// workspace's colour or its development strip — that is decided above
// the navigator, by route (app/shell/layer_chrome.dart), so every page
// pushed from here wears it too.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../directory/presentation/directory_screen.dart';
import 'me_account_tab.dart';
import 'me_home_tab.dart';
import 'me_messages_tab.dart';

/// The four tabs, in bar order; the wire name is the `tab` query value.
enum MeTab {
  home('home'),
  discover('discover'),
  messages('messages'),
  me('me');

  const MeTab(this.wire);

  final String wire;

  static MeTab fromQuery(String? wire) =>
      values.where((t) => t.wire == wire).firstOrNull ?? MeTab.home;
}

class MeShell extends StatefulWidget {
  const MeShell({super.key, this.tab = MeTab.home});

  final MeTab tab;

  @override
  State<MeShell> createState() => _MeShellState();
}

class _MeShellState extends State<MeShell> {
  late MeTab _tab = widget.tab;

  /// Tabs are built on first visit and kept: Discover searches and
  /// Messages polls, and neither should start before it is opened.
  late final Set<MeTab> _visited = {widget.tab};

  @override
  void didUpdateWidget(MeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) _show(widget.tab);
  }

  void _show(MeTab tab) => setState(() {
        _tab = tab;
        _visited.add(tab);
      });

  Widget _page(MeTab tab) => switch (tab) {
        MeTab.home => MeHomeTab(onDiscover: () => _show(MeTab.discover)),
        MeTab.discover => const DirectoryScreen(),
        MeTab.messages => const MeMessagesTab(),
        MeTab.me => const MeAccountTab(),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const ValueKey('me-shell'),
      body: IndexedStack(
        index: _tab.index,
        children: [
          for (final tab in MeTab.values)
            _visited.contains(tab) ? _page(tab) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _show(MeTab.values[i]),
        destinations: [
          NavigationDestination(
            key: const ValueKey('me-tab-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n?.meTabHome ?? 'Home',
          ),
          NavigationDestination(
            key: const ValueKey('me-tab-discover'),
            icon: const Icon(Icons.travel_explore_outlined),
            selectedIcon: const Icon(Icons.travel_explore),
            label: l10n?.meTabDiscover ?? 'Discover',
          ),
          NavigationDestination(
            key: const ValueKey('me-tab-messages'),
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: l10n?.meTabMessages ?? 'Messages',
          ),
          NavigationDestination(
            key: const ValueKey('me-tab-me'),
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n?.meTabMe ?? 'Me',
          ),
        ],
      ),
    );
  }
}
