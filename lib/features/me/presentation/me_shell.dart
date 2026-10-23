// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the Me layer: the person's own home, owned by nobody else.
//
// Four tabs, reachable with zero workspaces: Home (my spaces), Discover,
// Messages and Me. The layer wears DesKilo's own ink-blue and never a
// workspace's colour or its development strip — that is decided above
// the navigator, by route (app/shell/layer_chrome.dart), so every page
// pushed from here wears it too.
//
// This is the shell the `personalShell` flag keeps when it is OFF; on, the
// five-destination personal shell (me_personal_shell.dart) takes the same
// MeTab table and the router owns the selected destination.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/shell_drawer.dart';
import '../../../core/backend/backend_settings.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/navigation_style.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../directory/presentation/directory_screen.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';
import '../../workspace/application/pending_invitation.dart';
import 'me_account_tab.dart';
import 'me_home_tab.dart';
import 'me_messages_tab.dart';
import 'task_wizard_entry.dart';

/// The one table of Me's destinations: the wire name is the legacy `tab`
/// query value, [path] the personal shell's address. [legacy] is the
/// four-tab shell's bar order (the flag off); [destinations] the five
/// branches of the personal shell (the flag on); [me] is a tab in the first
/// and the account utility in the second. Each is one destination of the
/// bar, the drawer, the rail and the sidebar alike.
enum MeTab {
  home('home', 'me-tab-home', Icons.home_outlined, Icons.home, '/me'),
  spaces('spaces', 'me-tab-spaces', Icons.workspaces_outline,
      Icons.workspaces, '/me/spaces'),
  discover('discover', 'me-tab-discover', Icons.travel_explore_outlined,
      Icons.travel_explore, '/me/discover'),
  messages('messages', 'me-tab-messages', Icons.forum_outlined, Icons.forum,
      '/me/messages'),
  data('data', 'me-tab-data', Icons.folder_shared_outlined,
      Icons.folder_shared, '/me/data'),
  me('me', 'me-tab-me', Icons.person_outline, null, '/me/account');

  const MeTab(
      this.wire, this.destinationKey, this.icon, this.selectedIcon, this.path);

  final String wire;

  /// The key of this tab's destination in the bar, the drawer, the rail and
  /// the sidebar alike, written out so the task recorder names each tab.
  final String destinationKey;
  final IconData icon;

  /// The bar's icon while the tab is open; null for Me, which shows the
  /// person's own avatar instead.
  final IconData? selectedIcon;

  /// Where the personal shell opens this destination.
  final String path;

  /// The four-tab shell, in bar order.
  static const List<MeTab> legacy = [home, discover, messages, me];

  /// The five destinations of the personal shell, in branch order.
  static const List<MeTab> destinations = [home, spaces, discover, messages, data];

  /// The four-tab shell's wording.
  String label(AppLocalizations l10n) => switch (this) {
    home => l10n.meTabHome,
    spaces => l10n.meMySpaces,
    discover => l10n.meTabDiscover,
    messages => l10n.meTabMessages,
    data => l10n.meTabData,
    me => l10n.uxProfileAccount,
  };

  /// The personal shell's wording: Overview leads, and the account is the
  /// Confidentiality-and-account utility.
  String destinationLabel(AppLocalizations l10n) => switch (this) {
    home => l10n.meTabOverview,
    me => l10n.meUtilityAccount,
    _ => label(l10n),
  };

  /// The personal shell's wording on a phone's bottom bar.
  String compactLabel(AppLocalizations l10n) => switch (this) {
    home => l10n.meTabOverviewShort,
    spaces => l10n.meTabSpacesShort,
    data => l10n.meTabDataShort,
    _ => destinationLabel(l10n),
  };

  /// The legacy tab a `tab` query names; Home for anything else.
  static MeTab fromQuery(String? wire) =>
      legacy.where((t) => t.wire == wire).firstOrNull ?? MeTab.home;

  /// The destination whose branch holds [path]: a page nested under a
  /// destination belongs to it (`/me/account` to Overview, `/me/messages/x`
  /// to Messages).
  static MeTab destinationOf(String path) {
    MeTab best = home;
    for (final tab in destinations) {
      final under = path == tab.path || path.startsWith('${tab.path}/');
      if (under && tab.path.length >= best.path.length) best = tab;
    }
    return best;
  }
}

/// #1652 — an invitation kept on this device is offered once per server
/// when Me opens on its home; [stillOnHome] is asked again after each wait,
/// since the person may have moved on meanwhile.
Future<void> offerKeptInvitation(
  WidgetRef ref,
  BuildContext context, {
  required bool Function() stillOnHome,
}) async {
  final invitations = ref.read(pendingInvitationsProvider);
  final arrived = ref.read(arrivedInvitationsProvider);
  try {
    final active = await ref.read(activeBackendProvider.future);
    if (!context.mounted || arrived.wasOfferedOn(active.url)) return;
    final text = await invitations.offeredOn(active);
    if (!context.mounted || text == null || !stillOnHome()) return;
    arrived
      ..markOfferedOn(active.url)
      ..hold(text);
    context.go('/onboarding?join=1');
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'workspace',
      'kept invitation unreadable',
      error: e,
      stackTrace: st,
    );
  }
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
    if (widget.tab == MeTab.home) {
      unawaited(offerKeptInvitation(ref, context,
          stillOnHome: () => mounted && _tab == MeTab.home &&
              GoRouter.of(context).state.uri.path == '/me'));
    }
  }

  /// Tabs are built on first visit and kept: Discover searches and
  /// Messages keeps its own polling once opened; before then only its badge refreshes.
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
    // Branches of the personal shell only; never a tab of this one.
    MeTab.spaces || MeTab.data => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Messages keeps its own polling once opened; before then only its
    // badge refreshes.
    if (!_visited.contains(MeTab.messages)) ref.watch(inboxBadgeRefreshProvider);
    final inbox = ref.watch(unifiedInboxProvider);
    final unread = inbox.isReloading ? 0 : inbox.value?.unread ?? 0;
    Widget icon(MeTab tab, IconData data) => tab == MeTab.messages && unread > 0
        ? Badge.count(count: unread, maxCount: 99, child: Icon(data)) : Icon(data);
    final menu = ref.watch(webShellProvider);
    final wideNavigation = menu &&
        MediaQuery.sizeOf(context).width >= kWideNavigationMinWidth &&
        MediaQuery.textScalerOf(context).scale(100) <= kWideNavigationMaxTextScale;
    final selected = MeTab.legacy.indexOf(_tab);
    Widget destination(MeTab tab, {required bool permanent}) => ListTile(
          key: ValueKey(tab.destinationKey),
          leading: icon(tab, tab.icon),
          title: Text(tab.label(l10n)),
          selected: _tab == tab,
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          selectedColor: Theme.of(context).colorScheme.onSecondaryContainer,
          onTap: () {
            if (!permanent) Navigator.of(context).pop();
            _show(tab);
          },
        );
    Widget navigation({bool permanent = false}) => SafeArea(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const PersonalAvatar(radius: 20),
                      title: Text(
                        '${l10n.appTitle} · ${l10n.meTabMe}',
                      ),
                    ),
                    const Divider(),
                    for (final tab in MeTab.legacy.takeWhile((t) => t != MeTab.me))
                      destination(tab, permanent: permanent),
                    // The task wizard sits between Messages and the profile.
                    TaskWizardEntry(
                        entryKey: 'me-drawer-task-wizard', closesDrawer: !permanent),
                    destination(MeTab.me, permanent: permanent),
                  ],
                ),
              );
    return Scaffold(
      key: const ValueKey('me-shell'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.appTitle} · ${l10n.meTabMe}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              _tab.label(l10n),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('me-profile-settings'),
            tooltip: l10n.uxProfileAccount,
            onPressed: () => _show(MeTab.me),
            icon: const PersonalAvatar(),
          ),
        ],
      ),
      drawer: menu && !wideNavigation
          ? Drawer(key: const ValueKey('me-drawer'), child: navigation()) : null,
      body: Row(children: [
        if (wideNavigation) ...[
          SizedBox(width: 220, child: Material(
            key: const ValueKey('me-sidebar'),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: navigation(permanent: true))),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: IndexedStack(
        index: selected,
        children: [
          for (final tab in MeTab.legacy)
            TickerMode(
              enabled: _tab == tab,
              child: _visited.contains(tab)
                  ? _page(tab)
                  : const SizedBox.shrink(),
            ),
        ],
      )),
      ]),
      bottomNavigationBar: menu
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => _show(MeTab.legacy[i]),
              destinations: [
                for (final tab in MeTab.legacy)
                  NavigationDestination(
                    key: ValueKey(tab.destinationKey),
                    icon: icon(tab, tab.icon),
                    selectedIcon: switch (tab.selectedIcon) {
                      final selected? => icon(tab, selected),
                      null => const PersonalAvatar(),
                    },
                    label: tab.label(l10n),
                  ),
              ],
            ),
    );
  }
}
