// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The personal shell: Me as five route-owned destinations.
//
// The router owns the selected destination (one StatefulShellRoute branch
// per destination, lib/app/routes/me_routes.dart); this widget composes the
// chrome around the branch navigators from the one MeTab table — a 248 dp
// sidebar on a wide window, an 80 dp rail on a medium one, a bottom bar on a
// phone, or the labelled navigation menu when the bar has no room or the
// person chose the menu. One header, one avatar, the Personal scope badge.
// A page open over a branch root (a conversation, the account) brings its
// own header and Back: the shell then draws no second header and, on a
// phone, no competing bar, and the branch keeps its stack for the way back.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/shell_drawer.dart';
import '../../../core/help/guide_site.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/navigation_style.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/personal_theme.dart';
import '../../directory/providers/messenger_providers.dart';
import '../../profile/presentation/widgets/personal_avatar.dart';
import '../providers/personal_shell_providers.dart';
import 'me_account_tab.dart';
import 'me_home_tab.dart';
import 'me_shell.dart';
import 'task_wizard_entry.dart';

/// What the shell route builds around its branches: the personal shell when
/// the flag is on, the bare branch navigators (holding the four-tab shell)
/// when it is off.
class MeShellSwitch extends ConsumerWidget {
  const MeShellSwitch({
    super.key,
    required this.navigationShell,
    required this.path,
  });

  final StatefulNavigationShell navigationShell;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(personalShellEnabledProvider)
          ? MePersonalShell(navigationShell: navigationShell, path: path)
          : navigationShell;
}

/// What `/me` shows: the Overview page inside the personal shell, or the
/// four-tab shell opened on [tab] when the flag is off.
class MeHomeRoot extends ConsumerWidget {
  const MeHomeRoot({super.key, this.tab});

  /// The legacy `tab` query value.
  final String? tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(personalShellEnabledProvider)
          ? const MeHomeTab()
          : MeShell(tab: MeTab.fromQuery(tab));
}

/// The Confidentiality-and-account utility at `/me/account`: the account
/// tab as a page of its own, with a header that leads back to the branch.
class MeAccountPage extends StatelessWidget {
  const MeAccountPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.meUtilityAccount)),
        body: const MeAccountTab(),
      );
}

class MePersonalShell extends ConsumerStatefulWidget {
  const MePersonalShell({
    super.key,
    required this.navigationShell,
    required this.path,
  });

  final StatefulNavigationShell navigationShell;

  /// The location's path: which page of which branch is open.
  final String path;

  @override
  ConsumerState<MePersonalShell> createState() => _MePersonalShellState();
}

class _MePersonalShellState extends ConsumerState<MePersonalShell>
    with WidgetsBindingObserver {
  /// Branches opened so far: Messages polls on its own once opened, and
  /// before then only its badge refreshes.
  late final Set<int> _visited = {widget.navigationShell.currentIndex};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.path == MeTab.home.path) {
      unawaited(offerKeptInvitation(ref, context,
          stillOnHome: () =>
              mounted && GoRouter.of(context).state.uri.path == MeTab.home.path));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The window changed: the layout class is read again from it.
  @override
  void didChangeMetrics() => setState(() {});

  /// Opens [tab]'s branch, restoring the stack it had — a reselect never
  /// resets a page the person left open.
  void _open(MeTab tab) =>
      widget.navigationShell.goBranch(MeTab.destinations.indexOf(tab));

  void _openAccount() => context.go(MeTab.me.path);

  Widget _icon(MeTab tab, IconData data, int unread) =>
      tab == MeTab.messages && unread > 0
          ? Badge.count(count: unread, maxCount: 99, child: Icon(data))
          : Icon(data);

  /// The destinations and the utilities as a list: the drawer and the
  /// sidebar.
  Widget _navigation({
    required bool permanent,
    required MeTab current,
    required int unread,
  }) {
    final l10n = context.l10n;
    void go(VoidCallback action) {
      if (!permanent) Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: ListView(
        children: [
          ListTile(
            leading: const PersonalAvatar(radius: 20),
            title: Text(l10n.appTitle),
            subtitle: const Row(mainAxisSize: MainAxisSize.min,
                children: [_MeScopeBadge()]),
          ),
          const Divider(),
          for (final tab in MeTab.destinations)
            ListTile(
              key: ValueKey(tab.destinationKey),
              leading: _icon(tab, tab.icon, unread),
              title: Text(tab.destinationLabel(l10n)),
              selected: tab == current,
              onTap: () => go(() => _open(tab)),
            ),
          const Divider(),
          ListTile(
            key: ValueKey(MeTab.me.destinationKey),
            leading: Icon(MeTab.me.icon),
            title: Text(MeTab.me.destinationLabel(l10n)),
            selected: widget.path.startsWith(MeTab.me.path),
            onTap: () => go(_openAccount),
          ),
          TaskWizardEntry(
              entryKey: 'me-drawer-task-wizard', closesDrawer: !permanent),
          ListTile(
            key: const ValueKey('me-utility-help'),
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.meUtilityHelp),
            trailing: const Icon(Icons.open_in_new),
            // The guide opens from the shell's own context: the row's is
            // gone once the drawer closes.
            onTap: () => go(() => unawaited(openGuide(ref, context))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shell = widget.navigationShell;
    final current = MeTab.destinations[shell.currentIndex];
    _visited.add(shell.currentIndex);
    if (!_visited.contains(MeTab.destinations.indexOf(MeTab.messages))) {
      ref.watch(inboxBadgeRefreshProvider);
    }
    final inbox = ref.watch(unifiedInboxProvider);
    final unread = inbox.isReloading ? 0 : inbox.value?.unread ?? 0;
    // The WINDOW decides the layout — not the reading column a frame may
    // lay the page in, and not the keyboard, which never changes the
    // window's size: the class does not jump while typing or on a frame
    // change.
    final view = View.of(context);
    final window = view.physicalSize / view.devicePixelRatio;
    final layout = personalLayoutOf(
      width: window.width,
      height: window.height,
      textScalePercent: MediaQuery.textScalerOf(context).scale(100),
      menuPreferred: ref.watch(webShellProvider),
    );
    final nested = MeTab.destinationOf(widget.path).path != widget.path;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    return Scaffold(
      key: const ValueKey('me-shell'),
      appBar: nested
          ? null
          : AppBar(
              toolbarHeight:
                  PersonalShellMetrics.headerHeightFor(layout, theme.platform),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.appTitle, style: theme.textTheme.labelLarge),
                    const SizedBox(width: AppSpacing.sm),
                    const _MeScopeBadge(),
                  ]),
                  Text(current.destinationLabel(l10n),
                      style: theme.textTheme.titleMedium),
                ],
              ),
              actions: [
                IconButton(
                  key: const ValueKey('me-profile-settings'),
                  tooltip: l10n.meUtilityAccount,
                  onPressed: _openAccount,
                  icon: const PersonalAvatar(),
                ),
              ],
            ),
      drawer: layout == PersonalLayout.menu
          ? Drawer(
              key: const ValueKey('me-drawer'),
              child: _navigation(
                  permanent: false, current: current, unread: unread))
          : null,
      body: Row(children: [
        if (layout == PersonalLayout.sidebar) ...[
          SizedBox(
            width: PersonalShellMetrics.sidebarWidth,
            child: Material(
              key: const ValueKey('me-sidebar'),
              color: tokens.subtle,
              child: FocusTraversalGroup(
                child: _navigation(
                    permanent: true, current: current, unread: unread),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        if (layout == PersonalLayout.rail) ...[
          _PersonalRail(current: current, unread: unread, onOpen: _open),
          const VerticalDivider(width: 1),
        ],
        // A branch's semantics must not hide the navigation beside it.
        Expanded(child: Semantics(container: true, child: shell)),
      ]),
      bottomNavigationBar: layout == PersonalLayout.bar && !nested
          ? NavigationBar(
              key: const ValueKey('me-bar'),
              height: PersonalShellMetrics.barHeightFor(theme.platform,
                  web: ref.watch(platformIsWebProvider)),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => _open(MeTab.destinations[i]),
              destinations: [
                for (final tab in MeTab.destinations)
                  NavigationDestination(
                    key: ValueKey(tab.destinationKey),
                    icon: _icon(tab, tab.icon, unread),
                    selectedIcon:
                        _icon(tab, tab.selectedIcon ?? tab.icon, unread),
                    label: tab.compactLabel(l10n),
                  ),
              ],
            )
          : null,
    );
  }
}

/// The Personal scope badge: this is the person's own layer, never a space.
class _MeScopeBadge extends StatelessWidget {
  const _MeScopeBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    return Container(
      key: const ValueKey('me-scope-badge'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs / 2),
      decoration: BoxDecoration(
        color: tokens.primaryTint,
        borderRadius: PersonalShellMetrics.controlRadiusAll,
      ),
      child: Text(
        context.l10n.meContextPersonal,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: tokens.primary),
      ),
    );
  }
}

/// The 80 dp rail of a medium window: the five destinations, icon over
/// label, each a 48 dp-plus target that names itself and its selection.
class _PersonalRail extends StatelessWidget {
  const _PersonalRail({
    required this.current,
    required this.unread,
    required this.onOpen,
  });

  final MeTab current;
  final int unread;
  final ValueChanged<MeTab> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = PersonalTheme.of(context);
    return Material(
      key: const ValueKey('me-rail'),
      color: tokens.subtle,
      child: SafeArea(
        child: SizedBox(
          width: PersonalShellMetrics.railWidth,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              for (final tab in MeTab.destinations)
                _RailItem(
                  itemKey: tab.destinationKey,
                  tab: tab,
                  label: tab.compactLabel(l10n),
                  selected: tab == current,
                  unread: tab == MeTab.messages ? unread : 0,
                  onTap: () => onOpen(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.itemKey,
    required this.tab,
    required this.label,
    required this.selected,
    required this.unread,
    required this.onTap,
  });

  /// The destination's key, on the target itself.
  final String itemKey;
  final MeTab tab;
  final String label;
  final bool selected;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final ink = selected ? tokens.primary : tokens.secondaryText;
    final icon = Icon(selected ? tab.selectedIcon ?? tab.icon : tab.icon,
        color: ink);
    return Semantics(
      selected: selected,
      child: InkWell(
        key: ValueKey(itemKey),
        borderRadius: PersonalShellMetrics.controlRadiusAll,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
              minHeight: PersonalShellMetrics.minTarget + AppSpacing.sm),
          margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? tokens.primaryTint : null,
            borderRadius: PersonalShellMetrics.controlRadiusAll,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unread > 0)
                Badge.count(count: unread, maxCount: 99, child: icon)
              else
                icon,
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
