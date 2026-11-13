// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The phone's top bar: the page's name in full on one line, and the
// controls that leave room for it. What does not fit goes behind one
// overflow button, by the order of priority of shell_app_bar.dart; the
// inbox and the account never leave.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/kit/row_menu.dart';
import 'shell_app_bar.dart';
import 'shell_title_bar.dart';
import 'space_chip.dart';

/// The room one control of the bar takes: an icon button's tap target.
const double shellControlExtent = kMinInteractiveDimension;

/// The phone's top bar for the branch at [currentIndex], titled [tabTitle].
class ShellPhoneBar extends ConsumerWidget implements PreferredSizeWidget {
  const ShellPhoneBar({
    super.key,
    required this.tabTitle,
    required this.currentIndex,
    required this.collapsible,
  });

  final String tabTitle;
  final int currentIndex;

  /// See [ShellTitleBar.collapsible].
  final bool collapsible;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = shellBarControls(context, ref, currentIndex: currentIndex);
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = _slots(context, constraints.maxWidth);
        var fit = fitShellControls(controls, slots: slots);
        // #3610 — search has a button only where every control still fits
        // beside it; a narrower bar keeps its controls (the drawer's first
        // entry and Ctrl/⌘+K open search there).
        if (fit.overflow.isNotEmpty) {
          fit = fitShellControls([
            for (final c in controls)
              if (c.id != shellSearchButtonId) c,
          ], slots: slots);
        }
        final shown = [for (final c in fit.shown) c.button];
        return ShellTitleBar(
          collapsible: collapsible,
          appBar: AppBar(
            title: SpaceChip(tabTitle: tabTitle),
            // The account keeps the bar's end; the overflow stands before it.
            actions: fit.overflow.isEmpty
                ? shown
                : [
                    ...shown.take(shown.length - 1),
                    ShellOverflow(
                      entries: [for (final c in fit.overflow) c.entry!],
                    ),
                    shown.last,
                  ],
          ),
        );
      },
    );
  }

  /// How many controls the bar holds beside the page's name in full.
  int _slots(BuildContext context, double width) {
    final style = DefaultTextStyle.of(
      context,
    ).style.merge(Theme.of(context).textTheme.titleMedium);
    final painter = TextPainter(
      text: TextSpan(text: tabTitle, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final title = painter.width;
    painter.dispose();
    // The menu button the drawer adds, the spacing the toolbar keeps on
    // either side of its title and around its actions, as the theme sets
    // them.
    final theme = AppBarTheme.of(context);
    final leading = Scaffold.maybeOf(context)?.hasDrawer ?? false
        ? theme.leadingWidth ?? kToolbarHeight
        : 0.0;
    final spacing = theme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
    final padding = theme.actionsPadding?.horizontal ?? 0;
    final room = width - leading - 2 * spacing - padding - title.ceil();
    return room <= 0 ? 0 : (room / shellControlExtent).floor();
  }
}

/// The controls [slots] buttons wide: every one when they fit; else the
/// most needed, one slot kept for the overflow button holding the rest.
({List<ShellBarControl> shown, List<ShellBarControl> overflow})
fitShellControls(
  List<ShellBarControl> controls, {
  required int slots,
}) {
  if (controls.length <= slots) return (shown: controls, overflow: const []);
  final byRank = [...controls]..sort((a, b) => a.rank.compareTo(b.rank));
  final staying = controls.where((c) => c.entry == null).length;
  final free = slots - staying - 1;
  final kept = <ShellBarControl>{
    for (final c in byRank.where((c) => c.entry != null).take(free < 0 ? 0 : free))
      c,
  };
  return (
    shown: [
      for (final c in controls)
        if (c.entry == null || kept.contains(c)) c,
    ],
    overflow: [
      for (final c in byRank)
        if (c.entry != null && !kept.contains(c)) c,
    ],
  );
}

/// The one overflow button: the kit's row menu, opened from a toolbar-sized
/// button. A screen reader reaches each entry as an action of the button.
class ShellOverflow extends StatefulWidget {
  const ShellOverflow({super.key, required this.entries});

  final List<RowAction> entries;

  @override
  State<ShellOverflow> createState() => ShellOverflowState();
}

class ShellOverflowState extends State<ShellOverflow> {
  final _menu = GlobalKey<RowMenuState>();

  @override
  // #3620 -- one named control: the menu's actions and the button's name
  // are the same node, not an unnamed wrapper beside a named button.
  Widget build(BuildContext context) => MergeSemantics(
    child: RowMenu(
      key: _menu,
      actions: widget.entries,
      keyPrefix: 'shell-overflow',
      button: RowMenuButton.none,
      expand: false,
      child: Builder(
        builder: (button) => IconButton(
          key: const ValueKey('shell-overflow-button'),
          icon: const Icon(Icons.more_vert),
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          onPressed: () => unawaited(_menu.currentState?.open(anchor: button)),
        ),
      ),
    ),
  );
}
