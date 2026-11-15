// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3893 — the desk's top bar gives the page's name its room first. The
// controls leave the bar by the order of priority the phone's bar uses
// (shell_app_bar.dart) and wait behind one overflow button; a name that
// still does not fit beside the controls that never leave wraps to a second
// line rather than losing its end. One rule for every page, at every width.
import 'package:flutter/material.dart';

import 'shell_app_bar.dart';
import 'shell_phone_bar.dart';

/// The height of a bar whose title wraps to a second line.
const double _wrapHeight = 80;

/// The desk's top bar: the title as [title] says it (given whether it must
/// wrap), [titleWidth] wide on one line, and the [controls] that fit.
class DeskTopBar extends StatelessWidget implements PreferredSizeWidget {
  const DeskTopBar({
    required this.title,
    required this.titleWidth,
    required this.controls,
    super.key,
  });

  final Widget Function({required bool wraps}) title;

  /// How wide the title is on one line.
  final double titleWidth;
  final List<ShellBarControl> controls;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = AppBarTheme.of(context);
      final spacing = theme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
      final padding = theme.actionsPadding?.horizontal ?? 0;
      final room = constraints.maxWidth - 2 * spacing - padding;
      // #4030 — the desk keeps the inbox on its bar: only the phone bar
      // may fold it into the menu.
      final kept = [
        for (final c in controls)
          if (c.id == shellEventsBellId) c.staying() else c,
      ];
      final slots = ((room - titleWidth.ceil()) / shellControlExtent)
          .floor()
          .clamp(0, kept.length);
      final fit = fitShellControls(kept, slots: slots);
      // With every control that may leave gone, is the name still wider
      // than the room?
      final staying = kept.where((c) => c.entry == null).length;
      final hasFolded = kept.any((c) => c.entry != null);
      final least = (staying + (hasFolded ? 1 : 0)) * shellControlExtent;
      final wraps = titleWidth.ceil() > room - least;
      final shown = [for (final c in fit.shown) c.button];
      return AppBar(
        key: const ValueKey('desk-top-bar'),
        automaticallyImplyLeading: false,
        toolbarHeight: wraps ? _wrapHeight : null,
        title: title(wraps: wraps),
        actions: fit.overflow.isEmpty
            ? shown
            : [
                ...shown.take(shown.length - 1),
                ShellOverflow(
                  entries: [for (final c in fit.overflow) c.entry!],
                  attention: fit.overflow.any((c) => c.attention),
                ),
                if (shown.isNotEmpty) shown.last,
              ],
      );
    },
  );
}
