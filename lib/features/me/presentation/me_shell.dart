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
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/trace/trace_logger.dart';
import '../../workspace/application/pending_invitation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/shell_drawer.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';

import '../../../l10n/app_localizations.dart';
import '../../directory/presentation/directory_screen.dart';
import '../../task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
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

class MeShell extends ConsumerStatefulWidget {
  const MeShell({super.key, this.tab = MeTab.home});

  final MeTab tab;

  @override
  ConsumerState<MeShell> createState() => _MeShellState();
}

class _MeShellState extends ConsumerState<MeShell> {
  late MeTab _tab = widget.tab;

  @override
  void initState() {
    super.initState();
    _offerKeptInvitation();
  }

  Future<void> _offerKeptInvitation() async {
    if (widget.tab != MeTab.home) return;
    final invitations = ref.read(pendingInvitationsProvider);
    final arrived = ref.read(arrivedInvitationsProvider);
    try {
      final active = await ref.read(activeBackendProvider.future);
      if (!mounted || arrived.wasOfferedOn(active.url)) return;
      final text = await invitations.offeredOn(active);
      if (!mounted || text == null || _tab != MeTab.home) return;
      if (GoRouter.of(context).state.uri.path != '/me') return;
      arrived.markOfferedOn(active.url);
      arrived.hold(text);
      context.go('/onboarding?join=1');
    } catch (e, st) {
      TraceLogger.instance.warn(
        'workspace',
        'kept invitation unreadable',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Tabs are built on first visit and kept: Discover searches and
  /// Messages polls, and neither should start before it is opened.
  late final Set<MeTab> _visited = {widget.tab};

  @override
  void didUpdateWidget(MeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      _tab = widget.tab;
      _visited.add(widget.tab);
    }
  }

  void _show(MeTab tab) {
    if (_tab == tab) return;
    context.go(tab == MeTab.home ? '/me' : '/me?tab=${tab.wire}');
  }

  Widget _page(MeTab tab) => switch (tab) {
    MeTab.home => const MeHomeTab(),
    MeTab.discover => const DirectoryScreen(embedded: true),
    MeTab.messages => const MeMessagesTab(),
    MeTab.me => const MeAccountTab(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final menu = ref.watch(webShellProvider);
    final labels = [
      l10n?.meTabHome ?? 'Home',
      l10n?.meTabDiscover ?? 'Discover',
      l10n?.meTabMessages ?? 'Messages',
      l10n?.meTabMe ?? 'Me',
    ];
    final icons = [
      Icons.home_outlined,
      Icons.travel_explore_outlined,
      Icons.forum_outlined,
      Icons.person_outline,
    ];
    return Scaffold(
      key: const ValueKey('me-shell'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n?.appTitle ?? 'DesKilo'} · ${l10n?.meTabMe ?? 'Me'}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              labels[_tab.index],
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('me-profile-settings'),
            tooltip: l10n?.meGroupProfile ?? 'My profile',
            onPressed: () => _show(MeTab.me),
            icon: const PersonalAvatar(),
          ),
        ],
      ),
      drawer: menu
          ? Drawer(
              key: const ValueKey('me-drawer'),
              child: SafeArea(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const PersonalAvatar(radius: 20),
                      title: Text(
                        '${l10n?.appTitle ?? 'DesKilo'} · ${l10n?.meTabMe ?? 'Me'}',
                      ),
                    ),
                    const Divider(),
                    for (final tab in MeTab.values) ...[
                      // The task wizard sits between Messages and the profile.
                      if (tab == MeTab.me &&
                          ref
                              .watch(enabledFeaturesSyncProvider)
                              .contains(WorkspaceFeature.taskRecorder))
                        ListTile(
                          key: const ValueKey('me-drawer-task-wizard'),
                          leading: const Icon(Icons.assistant_navigation),
                          title: Text(l10n?.taskWizardTitle ?? 'Task wizard'),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push(taskWizardRoute);
                          },
                        ),
                      // Me is the profile button at the top right already.
                      if (tab != MeTab.me)
                        ListTile(
                          key: ValueKey('me-tab-${tab.wire}'),
                          leading: Icon(icons[tab.index]),
                          title: Text(labels[tab.index]),
                          selected: _tab == tab,
                          onTap: () {
                            Navigator.of(context).pop();
                            _show(tab);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            )
          : null,
      body: IndexedStack(
        index: _tab.index,
        children: [
          for (final tab in MeTab.values)
            _visited.contains(tab) ? _page(tab) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: menu
          ? null
          : NavigationBar(
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
                  selectedIcon: const PersonalAvatar(),
                  label: l10n?.meTabMe ?? 'Me',
                ),
              ],
            ),
    );
  }
}
