// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/lexicon.dart';
import '../../core/motion/motion.dart';
import '../../features/events/providers/attention_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/money/presentation/widgets/invoice_form_sheet.dart';
import '../../features/workspace/providers/conversation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_scaffold.dart';
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
    // #1306 / #3551 — the one destination table the bar and the drawer
    // render: a business with places keeps its branch list exactly; one
    // without leads with Overview, Clients, Invoices, Messages.
    final permissions = ref.watch(myPermissionsProvider);
    final navs = shellNavFor(features, permissions);
    final visibleBranches = [for (final n in navs) n.branch];
    // Unknown permissions (the membership did not load) hide nothing: the
    // hub itself explains what went wrong.
    final center = shellCenterActionFor(
      features,
      permissions,
      membershipKnown: ref.watch(myMemberProvider).value != null,
    );
    final path = GoRouterState.of(context).uri.path;
    final selectedPosition = navs.indexWhere(
      (n) => n.selectedAt(branch: navigationShell.currentIndex, path: path),
    );
    // The web navigates through a drawer (every destination one tap
    // away, the full height for content); native keeps the bar.
    final webShell = ref.watch(webShellProvider);
    Widget navigation({bool permanent = false, bool rail = false}) => ShellDrawer(
      permanent: permanent, rail: rail,
      tabTitles: tabTitles, visibleBranches: visibleBranches, navs: navs,
      currentIndex: navigationShell.currentIndex, pendingEvents: pendingEvents,
      onBranch: (branch) => navigationShell.goBranch(branch,
          initialLocation: branch == navigationShell.currentIndex),
    );
    // #3060 F7 — the overview sits in the first branch but is not its alerts:
    // the bar names what is on screen.
    final tabTitle = path == '/workspace-overview'
        ? l10n.overviewTitle
        : tabTitles[navigationShell.currentIndex];
    // #1818 — one navigation shell at a time: see ShellSlot.
    final page = FadeInOnChange(
      changeKey: navigationShell.currentIndex,
      child: ShellSlot(child: navigationShell),
    );
    final actions = shellBarActions(context, ref,
        currentIndex: navigationShell.currentIndex);
    // #3603 — from the expanded window class, the desk, on every platform.
    // #3603 — from the expanded window class the desk is drawn around the
    // whole app (desk_frame.dart): the tab is only its page, on the
    // scaffold a tab page always had.
    if (deskShownAt(context, path, inBusiness: true)) {
      return Scaffold(body: page);
    }
    final barHidden = ref.watch(shellBarHiddenProvider).value ?? false;
    return Scaffold(
      drawer: webShell ? navigation() : null,
      // #1322 — the title bar leaves with the bottom bar: one gesture,
      // one progress, a real full-screen view. The web shell has no bar
      // to follow, and neither does a shell without one.
      appBar: ShellTitleBar(
        collapsible: !webShell && navs.isNotEmpty,
        appBar: AppBar(
          // #1823 — the chip names the space; the tab sits under it.
          title: SpaceChip(tabTitle: tabTitle),
          actions: actions,
        ),
      ),
      // #611 — the tab switch fades the incoming branch in. The
      // FadeIndexedStack pattern: the shell's IndexedStack (and with it
      // the #111 per-tab keep-alive state) stays untouched; only an
      // opacity layer above it animates, keyed by the active branch.
      body: page,
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
      bottomNavigationBar:
          webShell || (navs.isEmpty && center == ShellCenterAction.none)
          ? null
          : _bottomBar(
              context,
              ref,
              navs: navs,
              center: center,
              selectedPosition: selectedPosition,
              badges: (
                calendar: calendarBadge,
                money: attention.money,
                unread: unreadMessages,
              ),
            ),
    );
  }

  /// The bottom bar: the destination table, and the centre action (the
  /// booking, or a new invoice for a business without places, #3551).
  Widget _bottomBar(
    BuildContext context,
    WidgetRef ref, {
    required List<ShellNav> navs,
    required ShellCenterAction center,
    required int selectedPosition,
    required ({int calendar, int money, int unread}) badges,
  }) {
    final l10n = context.l10n;
    final tabTitles = shellTabTitles(context, l10n);
    final newInvoice = center == ShellCenterAction.newInvoice;
    void openNav(ShellNav nav) => nav.location != null
        ? context.go(nav.location!)
        : navigationShell.goBranch(
            nav.branch,
            initialLocation: nav.branch == navigationShell.currentIndex,
          );
    return ShellBottomBar(
              // -1 when no side tab matches what is on screen — on the
              // Reserve hub (the centre button carries the indication
              // instead) and for one redirect frame of a gated branch.
              selectedIndex: selectedPosition,
              showReserve: center != ShellCenterAction.none,
              reserveSelected: center == ShellCenterAction.reserve &&
                  navigationShell.currentIndex == ShellBranch.reserve,
              onDestinationSelected: (position) => openNav(navs[position]),
              destinations: [
                for (final nav in navs)
                  if (nav.id == 'overview')
                    ShellDestination(
                      icon: const Icon(Icons.space_dashboard_outlined),
                      selectedIcon: const Icon(Icons.space_dashboard),
                      label: l10n.overviewTitle,
                    )
                  else
                    shellDestinationFor(
                      nav.branch,
                      tabTitles: tabTitles,
                      calendarBadge: badges.calendar,
                      moneyBadge: badges.money,
                      unreadMessages: badges.unread,
                    ),
              ],
              reserveLabel: newInvoice
                  ? l10n.invoiceCreate
                  : lexiconText(
                      context,
                      key: 'shellReserveButton',
                      fallback: l10n.shellReserveButton,
                    ),
              centerIcon: newInvoice
                  ? Icons.post_add_outlined
                  : Icons.event_seat_outlined,
              centerSelectedIcon:
                  newInvoice ? Icons.post_add : Icons.event_seat,
              // A branch switch, not a push — the bar (and this button)
              // stay visible and functional on the hub. #3551 — without
              // places it opens the invoice form where the person is.
              onReservePressed: newInvoice
                  ? () => showInvoiceIssueSheet(context, ref)
                  : () => navigationShell.goBranch(
                      ShellBranch.reserve,
                      initialLocation:
                          navigationShell.currentIndex == ShellBranch.reserve,
                    ),
            );
  }
}
