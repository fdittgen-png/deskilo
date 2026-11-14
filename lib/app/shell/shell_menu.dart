// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 — the business's navigation for one person, assembled once: the
// drawer and the desk's sidebar and rail render it, and the desk's top bar
// and window title name the place a route declares from the same entries.
// It was the first half of ShellDrawer.build; the entries are unchanged.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/workspace/domain/workspace_permission.dart'
    show showsMemberAccountMenu;
import '../../features/workspace/presentation/widgets/setup_resume_banner.dart'
    show setupGuideOpenFor;
import '../../features/workspace/presentation/widgets/workspace_reports.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_classes.dart' show placeOf;
import 'shell_destinations.dart';
import 'shell_drawer_entries.dart';
import 'shell_nav_groups.dart';

/// The shell's tabs as the navigation offers them: their titles, the ones
/// shown, the destination table (#3551), the open one (-1 outside the tabs)
/// and how one is opened.
typedef ShellTabs = ({
  List<String> tabTitles,
  List<int> visibleBranches,
  List<ShellNav>? navs,
  int currentIndex,
  ValueChanged<int> onBranch,
});

/// One part of the desk's breadcrumb: a label, and the entry it opens.
typedef DeskCrumb = ({String label, DrawerEntry? entry});

/// #3789 — [crumbs] followed by the page's own [name] ("Settings ›
/// Colours"): only when the page has one and it is not the place's own
/// name already.
List<DeskCrumb> withPageName(List<DeskCrumb> crumbs, String? name) =>
    name == null || crumbs.isEmpty || crumbs.last.label == name
    ? crumbs
    : [...crumbs, (label: name, entry: null)];

/// The entries of the navigation, in the groups the drawer shows them in.
class ShellMenu {
  ShellMenu._({
    required this.navigation,
    required this.administration,
    required this.reporting,
    required this.account,
    required this.groups,
  });

  /// Reads what decides the entries and assembles them. [permanent]: shown
  /// beside the page (a tap does not close a drawer first).
  factory ShellMenu.of(
    BuildContext context,
    WidgetRef ref, {
    required bool permanent,
    required ShellTabs tabs,
    VoidCallback? openToPay,
    VoidCallback? openBankStatements,
  }) {
    final (:tabTitles, :visibleBranches, :navs, :currentIndex, :onBranch) =
        tabs;
    final uri = GoRouter.of(context).routeInformationProvider.value.uri;
    final path = uri.path;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    void go(String route, {bool push = true}) {
      if (!permanent) Navigator.of(context).pop();
      if (push) {
        unawaited(context.push(route));
      } else {
        context.go(route);
      }
    }

    final entries = DrawerEntries(
      context: context,
      features: features,
      permissions: perms,
      // #1598 — the effective permission set, watched, decides the account
      // entry's name in the drawer exactly as it does in the app bar.
      accountMenu: showsMemberAccountMenu(
        features: features,
        permissions: perms,
      ),
      permanent: permanent,
      visibleBranches: visibleBranches,
      navs: navs,
      path: path,
      tabTitles: tabTitles,
      currentIndex: currentIndex,
      onBranch: onBranch,
      go: go,
      setupOpen: setupGuideOpenFor(ref, workspace?.id),
      openToPay: openToPay,
      openBankStatements: openBankStatements,
    );
    final administration = [
      ...entries.setupGuide(),
      ...entries.administration(),
    ];
    final member = ref.watch(myMemberProvider).value;
    final sections = reportingSections(
      features: features,
      permissions: perms,
      isAdmin: member?.isAdmin ?? false,
      actsAsOwner: member?.actsAsOwner ?? false,
    );
    final section = uri.queryParameters['section'];
    bool onSection(String id) =>
        path == '/reports' &&
        (section ?? sections.where((s) => s != 'analytics').firstOrNull) == id;
    final reporting = entries.reporting(
      sections: sections,
      onSection: onSection,
    );
    return ShellMenu._(
      navigation: entries.navigation(),
      administration: administration,
      reporting: reporting,
      account: entries.account(),
      groups: navGroupsOf(
        entries,
        administration: administration,
        reporting: reporting,
      ),
    );
  }

  final List<DrawerEntry> navigation;
  final List<DrawerEntry> administration;
  final List<DrawerEntry> reporting;
  final List<DrawerEntry> account;
  final List<NavGroup> groups;

  /// #3603 — where [path] sits, as the sidebar shows it: the innermost group
  /// and the current entry ("Purchases › Suppliers"), the entry alone for a
  /// destination outside any group, the group alone for a route placed on a
  /// group with no entry current. Empty when the place is not offered to
  /// this person (its feature is off): nothing is named, nothing selected.
  /// An entry's crumb opens its page, the way back from a page opened on it.
  List<DeskCrumb> crumbsOf(String path) {
    for (final e in [...navigation, ...account]) {
      if (entryIsCurrent(e, path)) return [(label: e.label, entry: e)];
    }
    final place = placeOf(path);
    List<DeskCrumb>? inGroup(NavGroup g) {
      for (final s in g.sub) {
        final found = inGroup(s);
        if (found != null) return found;
      }
      for (final e in g.entries) {
        if (entryIsCurrent(e, path)) {
          return [(label: g.title, entry: null), (label: e.label, entry: e)];
        }
      }
      return g.id == place && !g.isEmpty
          ? [(label: g.title, entry: null)]
          : null;
    }

    for (final g in groups) {
      final found = inGroup(g);
      if (found != null) return found;
    }
    return const [];
  }
}
