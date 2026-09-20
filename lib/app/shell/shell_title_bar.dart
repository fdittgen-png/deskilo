// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell_bar_collapse.dart';
import 'shell_bar_visibility.dart';

/// The shell's title bar, leaving with the bottom bar (#1322).
///
/// The swipe-away view promised "a full-screen view" and delivered the
/// bottom half of one: on the plan canvas the title bar is the larger
/// piece of chrome. It now collapses on the SAME progress the bottom bar
/// reads — published by the one controller in [ShellBarCollapse] — so
/// the two follow the finger together mid-drag and settle on the same
/// frame. Nothing new to learn: the three ways back restore both.
///
/// ## What stays
///
/// The status-bar inset. Only the toolbar collapses, sliding up under
/// the phone's status bar, so content never runs beneath the clock. The
/// development strip lives outside the `Scaffold` (`app.dart`) and is
/// not touched.
///
/// ## Here the layout follows the finger
///
/// The bottom bar quantises its LAYOUT to two heights: a body growing at
/// its bottom edge reveals more of itself, and nobody sees the extra rows
/// arrive. The top is the opposite case — every row hangs from the title
/// bar, and a quantised height would drop the whole plan by a toolbar in
/// one frame at the end of the gesture. So this height is continuous and
/// the body reflows with it, for the dozen frames the bar is moving.
class ShellTitleBar extends ConsumerWidget implements PreferredSizeWidget {
  const ShellTitleBar({
    super.key,
    required this.appBar,
    required this.collapsible,
  });

  /// The bar as the shell builds it. Its [AppBar.title] and
  /// [AppBar.actions] are what the collapsing bar shows.
  final AppBar appBar;

  /// False on the web shell, which navigates through a drawer and has no
  /// bottom bar to follow: there the title bar never moves.
  final bool collapsible;

  @override
  Size get preferredSize => appBar.preferredSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!collapsible) return appBar;
    final hidden = ref.watch(shellBarHiddenProvider).value ?? false;
    return ValueListenableBuilder<double>(
      valueListenable: ref.watch(shellBarProgressProvider),
      builder: (context, progress, _) {
        final t = progress.clamp(0.0, 1.0);
        final inset = MediaQuery.paddingOf(context).top;
        final toolbar = AppBar.preferredHeightFor(context, preferredSize);
        // Title and actions fade on the bottom bar's curve, so neither
        // bar reaches its last pixels still carrying legible text — and
        // nothing is left showing through the status-bar strip.
        final opacity = shellBarContentOpacity(t);
        final title = appBar.title;
        final actions = appBar.actions;
        return SizedBox(
          key: const ValueKey('shell-title-bar'),
          height: inset + toolbar * (1 - t),
          child: ClipRect(
            child: OverflowBox(
              // Bottom-anchored: the toolbar's top edge passes under the
              // status bar first, so the bar slides UP out of view — the
              // mirror of the bottom bar leaving downwards.
              alignment: Alignment.bottomCenter,
              minHeight: inset + toolbar,
              maxHeight: inset + toolbar,
              child: IgnorePointer(
                ignoring: hidden,
                child: ExcludeSemantics(
                  key: const ValueKey('shell-title-bar-semantics'),
                  excluding: hidden,
                  child: AppBar(
                    title: title == null
                        ? null
                        : Opacity(opacity: opacity, child: title),
                    actions: actions == null
                        ? null
                        : [
                            Opacity(
                              opacity: opacity,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions,
                              ),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
