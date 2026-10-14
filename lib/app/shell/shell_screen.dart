// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/lexicon.dart';
import '../../core/motion/motion.dart';
import '../../features/events/providers/attention_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/conversation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'shell_app_bar.dart';
import 'shell_bar_visibility.dart';
import 'shell_bottom_bar.dart';
import 'shell_destinations.dart';
import 'shell_drawer.dart';
import 'shell_effects.dart';
import 'shell_slot.dart';
import 'shell_tabs.dart';
import 'shell_title_bar.dart';
import 'space_chip.dart';

/// Bottom-navigation shell hosting the branch destinations (spec §13).
/// Settings is not a tab — it is the top-right app-bar action, as in
/// Sparkilo; the events feed sits behind the app-bar bell beside it.
///
/// #2493 — build only composes: the session-wide effects live in
/// shell_effects.dart (owned by the ShellSession), the destinations in
/// shell_tabs.dart and the app bar's actions in shell_app_bar.dart.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    watchShellEffects(ref, l10n);
    final tabTitles = shellTabTitles(context, l10n);

    // Per-workspace feature gating (#146): the router branches stay fixed,
    // but disabled features drop their destination — so the bottom-bar
    // position and the branch index diverge and must be mapped both ways.
    // Messages (and Settings in the app bar) are core and never gated —
    // a workspace with no messaging surface has no way to reach a
    // conversation someone already sent it.
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #707 — the two counts SEPARATE again. The Messages badge counts
    // unread conversations; the bell counts pending confirmations. #702
    // had summed them onto one destination, and one number for two
    // different kinds of "something needs you" told nobody which.
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final pendingEvents = ref.watch(myPendingEventCountProvider).value ?? 0;
    final attention = ref.watch(workspaceAttentionProvider);
    final calendarBadge =
        decisionSignalOnCalendar(features) ? pendingEvents : 0;
    // #1306 — the one destination list the drawer renders too.
    final visibleBranches =
        visibleShellBranches(features, ref.watch(myPermissionsProvider));
    // Unknown permissions (the membership did not load) hide nothing: the
    // hub itself explains what went wrong.
    final showReserve = ref.watch(myMemberProvider).value == null ||
        ref
            .watch(myPermissionsProvider)
            .contains(WorkspacePermission.makeReservations);
    final selectedPosition =
        visibleBranches.indexOf(navigationShell.currentIndex);

    // The web navigates through a drawer (every destination one tap
    // away, the full height for content); native keeps the bar.
    final webShell = ref.watch(webShellProvider);
    final wideNavigation = webShell && MediaQuery.sizeOf(context).width >= 900 &&
        MediaQuery.textScalerOf(context).scale(100) <= 150;
    Widget navigation({bool permanent = false}) => ShellDrawer(
      permanent: permanent,
      tabTitles: tabTitles, visibleBranches: visibleBranches,
      currentIndex: navigationShell.currentIndex, pendingEvents: pendingEvents,
      onBranch: (branch) => navigationShell.goBranch(branch,
          initialLocation: branch == navigationShell.currentIndex),
    );
    final barHidden = ref.watch(shellBarHiddenProvider).value ?? false;
    return Scaffold(
      drawer: webShell && !wideNavigation ? navigation() : null,
      // #1322 — the title bar leaves with the bottom bar: one gesture,
      // one progress, a real full-screen view. The web shell has no bar
      // to follow, and neither does a shell without one.
      appBar: ShellTitleBar(
        collapsible: !webShell && visibleBranches.isNotEmpty,
        appBar: AppBar(
          // #1823 — the chip names the space; the tab sits under it.
          title: SpaceChip(tabTitle: tabTitles[navigationShell.currentIndex]),
          actions: shellBarActions(context, ref,
              currentIndex: navigationShell.currentIndex),
        ),
      ),
      // #611 — the tab switch fades the incoming branch in. The
      // FadeIndexedStack pattern: the shell's IndexedStack (and with it
      // the #111 per-tab keep-alive state) stays untouched; only an
      // opacity layer above it animates, keyed by the active branch.
      body: Row(children: [
        if (wideNavigation) ...[
          // #2313 — wide enough for a menu label on one line.
          SizedBox(width: 272, child: FocusTraversalGroup(child: navigation(permanent: true))),
          const VerticalDivider(width: 1),
        ],
        // A branch route's semantics must not hide the sibling navigation.
        Expanded(child: Semantics(container: true, child: FadeInOnChange(
        changeKey: navigationShell.currentIndex,
        // #1818 — one navigation shell at a time: see ShellSlot.
        child: ShellSlot(child: navigationShell),
      ))),
      ]),
      // ONE destination is enough (#702).
      //
      // The old guard hid the whole bar below two, on the reasoning that
      // a notch wants a tab on either side. It was safe while the
      // ungated Members tab guaranteed a second one — and #702 moved
      // Members into the inbox, so a workspace with Calendar and Money
      // both off is down to the inbox alone. Hiding the bar there takes
      // the RAISED RESERVE BUTTON with it: the app's core action, on the
      // one surface that has no other way to reach it.
      //
      // The bar lays a single tab out on the leading side and leaves the
      // other blank, which looks sparse and works.
      // #1173 — the full-screen view. Only while the bar is swiped away
      // does the body run behind the bottom strip: the Reserve button
      // floats over the content and the whole bar's height is given
      // back. With the bar showing this is false, so every tab lays out
      // exactly as it always did.
      extendBody: barHidden,
      bottomNavigationBar: webShell || (visibleBranches.isEmpty && !showReserve)
          ? null
          : ShellBottomBar(
              // -1 when no side tab matches the active branch — on the
              // Reserve hub (the centre button carries the indication
              // instead) and for one redirect frame of a gated branch.
              // Never coerce to 0: that painted Plan as selected while
              // the hub was the loaded form.
              selectedIndex: selectedPosition,
              showReserve: showReserve,
              reserveSelected:
                  navigationShell.currentIndex == ShellBranch.reserve,
              onDestinationSelected: (position) => navigationShell.goBranch(
                visibleBranches[position],
                initialLocation:
                    visibleBranches[position] == navigationShell.currentIndex,
              ),
              destinations: [
                for (final branch in visibleBranches)
                  shellDestinationFor(
                    branch,
                    tabTitles: tabTitles,
                    calendarBadge: calendarBadge,
                    moneyBadge: attention.money,
                    unreadMessages: unreadMessages,
                  ),
              ],
              reserveLabel: lexiconText(context, key: 'shellReserveButton', fallback: l10n.shellReserveButton),
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
