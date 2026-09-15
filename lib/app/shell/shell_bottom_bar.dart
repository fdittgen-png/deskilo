// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notched_bar_border.dart';
import 'shell_bar_collapse.dart';
import 'shell_bar_double_tap.dart';
import 'shell_bar_visibility.dart';
import 'shell_center_button.dart';
import 'shell_swipe_coach_mark.dart';

/// Fixed geometry of the notched bottom bar (#207).
///
/// Ported from the Sparkilo shell (portrait values only — DesKilo has no
/// landscape-specific bar). Pinned by
/// test/app/shell/shell_bottom_bar_test.dart so a stray edit cannot
/// silently reshape the bar.
abstract final class ShellBarMetrics {
  /// Height of the coloured bar itself.
  static const double barHeight = 64;

  /// Head-room strip above the bar the docked centre button rises into.
  static const double rise = 24;

  /// Reserved horizontal gap between the tab halves that the docked
  /// button straddles (>= 2 * notch radius so tabs clear the notch walls).
  static const double centerGap = 76;

  /// Diameter of the raised circular Reserve button.
  static const double buttonDiameter = 56;

  /// Breathing room between the button edge and the notch wall.
  static const double notchMargin = 6;

  /// Radius of the concave scallop carved into the bar's top edge.
  static const double notchRadius = buttonDiameter / 2 + notchMargin;

  /// Icon size inside the flat side tabs.
  static const double tabIconSize = 24;

  /// Icon size inside the raised centre button.
  static const double buttonIconSize = 28;

  /// Width of the surface-coloured seat ring around the centre button.
  static const double buttonRingWidth = 2.5;

  /// Height the widget keeps for itself in the full-screen view (#1173):
  /// the Reserve button alone, which stays put as the way back. The
  /// shell sets `extendBody` while hidden, so the body runs behind even
  /// this strip and the button floats over the content.
  static const double hiddenHeight = buttonDiameter;

  /// Height the widget occupies with the bar showing.
  static const double shownHeight = barHeight + rise;

  /// #1183 — the same bar on a phone held sideways.
  ///
  /// A 1080 px-tall landscape screen gave 88 of its 1080 to a bar sized
  /// for a 2316 px portrait one — eight per cent of the screen, on the
  /// axis that has none to spare. Sparkilo drops its bar for exactly
  /// this reason, and the tabs lose nothing by it: an `IconButton` is
  /// 48 dp, so the touch target is untouched and only the padding goes.
  static const double barHeightShort = 48;

  /// The bar is measured against HEIGHT, not orientation: a tablet in
  /// landscape has plenty of room and keeps the portrait bar, while a
  /// phone in portrait with the keyboard up does not need this.
  static const double shortScreenHeight = 500;

  static double barHeightOf(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortScreenHeight
          ? barHeightShort
          : barHeight;

  static double shownHeightOf(BuildContext context) =>
      barHeightOf(context) + rise;
}

/// One flat tab of the [ShellBottomBar] — icon, label, selected state.
///
/// Mirrors [NavigationDestination] so [ShellScreen] keeps its per-branch
/// feature gating untouched; icons are widgets so badged icons keep
/// working (the Events tab carried one until #230 moved the feed to the
/// app-bar bell).
class ShellDestination {
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Sparkilo-style notched bottom navigation bar (#207), with its
/// swipe-away full-screen view (#1173).
///
/// The app's core action — Reserve — is a raised, primary-tinted circular
/// button docked into a concave notch carved into the bar's top edge; the
/// branch destinations are flat tabs flanking it, split around the centre
/// gap by index halving (4 tabs -> 2+2, 3 -> 2+1, 2 -> 1+1).
///
/// A downward swipe (or a double-tap) slides the tab surface out and
/// leaves the Reserve button behind, giving the whole strip back to the
/// content. See [ShellBarHidden] for the three ways back.
class ShellBottomBar extends ConsumerWidget {
  final List<ShellDestination> destinations;

  /// Selected destination, or `-1` while no visible tab matches the
  /// active branch (one frame during a gated-branch redirect).
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Tap handler of the raised centre Reserve button.
  final VoidCallback onReservePressed;

  /// Localized tooltip / semantic label of the Reserve button.
  final String reserveLabel;

  /// Whether the Reserve hub is the loaded form: the centre button is the
  /// bar's selection indicator then (filled icon, selected semantics) and
  /// [selectedIndex] is `-1` so no side tab claims the highlight.
  final bool reserveSelected;

  const ShellBottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onReservePressed,
    required this.reserveLabel,
    this.reserveSelected = false,
  });

  /// The bar holds no state of its own any more.
  ///
  /// It used to carry a `_settled` latch so the first, asynchronously
  /// resolved value of the preference landed without animating. That
  /// belongs to whoever owns the animation, which is now
  /// [ShellBarCollapse] — and two copies of one latch is precisely the
  /// drift this change exists to remove.
  Future<void> _setHidden(WidgetRef ref, bool hidden) async {
    await ref.read(shellBarHiddenProvider.notifier).set(hidden);
    // Performing the gesture is the best possible proof it was learned.
    await ref.read(shellSwipeCoachSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = ref.watch(shellBarHiddenProvider).value ?? false;
    // A hint can only appear once the flag it is gated on has resolved,
    // and never while the bar is already hidden: the gesture has plainly
    // been found.
    final coachSeen = ref.watch(shellSwipeCoachSeenProvider).value ?? true;
    final showCoach = !hidden && !coachSeen;

    // Tabs left of the centre gap: ceil-half of the destinations, so an
    // odd count keeps the heavier side leading (3 -> 2+1).
    final leftCount = (destinations.length + 1) ~/ 2;

    // Material both CLIPS the notch and casts a shadow that follows the
    // notched silhouette automatically (it derives its elevation shadow
    // from the ShapeBorder path), so no separate upward shadow painter is
    // needed.
    final bar = Material(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: theme.brightness == Brightness.dark ? 3 : 1,
      shadowColor: theme.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.12),
      shape: const NotchedBarBorder(notchRadius: ShellBarMetrics.notchRadius),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: ShellBarMetrics.barHeightOf(context),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < leftCount; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
            ),
            // Reserved gap the docked button straddles.
            const SizedBox(width: ShellBarMetrics.centerGap),
            Expanded(
              child: Row(
                children: [
                  for (var i = leftCount; i < destinations.length; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return MediaQuery.withClampedTextScaling(
      // Clamp text scaling so labels grow with the OS setting but never
      // past what the fixed-height bar can show.
      maxScaleFactor: 1.3,
      child: SafeArea(
        top: false,
        child: ShellBarCollapse(
          // The finger drives the progress directly, and the bar's own
          // height is the distance that covers the whole travel: the
          // control moves at roughly life size, which is what makes it
          // feel pulled rather than triggered.
          dragExtent: ShellBarMetrics.barHeightOf(context),
          builder: (context, t) => _frame(
            context: context,
            ref: ref,
            t: t,
            hidden: hidden,
            showCoach: showCoach,
            bar: bar,
          ),
        ),
      ),
    );
  }

  /// One frame of the collapse, at progress [t] (0 shown, 1 hidden).
  ///
  /// What used to be here was an `AnimatedSize`, an `AnimatedSlide` and,
  /// fatally, a plain `Align` whose alignment flipped between
  /// `topCenter` and `bottomCenter`. `Align` is not `AnimatedAlign`, so
  /// the Reserve button JUMPED its entire travel on the first frame and
  /// then sat perfectly still while everything around it animated for
  /// the remaining 220 ms — across the part of the transition anyone is
  /// actually watching, the anchor their eye should follow was
  /// stationary, and it had already moved before they could track it.
  /// That is the whole reason this read as "a bar leaves and a button
  /// arrives" rather than as one control changing shape.
  ///
  /// ## Chrome is continuous; LAYOUT is quantised
  ///
  /// The box height is what every body in the app reads as
  /// `MediaQuery.padding.bottom`, and `ShellScreen` flips `extendBody`
  /// on it. A height that followed `t` would relayout the plan canvas,
  /// the invoice lists and the month grid on every frame of every swipe.
  /// So it takes the shown value for the whole gesture and only drops at
  /// the far end, where the surface has already gone and nothing is
  /// drawn in the difference. The box is bottom-anchored, so the button
  /// does not move when it changes.
  Widget _frame({
    required BuildContext context,
    required WidgetRef ref,
    required double t,
    required bool hidden,
    required bool showCoach,
    required Widget bar,
  }) {
    final shown = ShellBarMetrics.shownHeightOf(context);
    // Two values across a whole drag, and never a third.
    final boxHeight = t >= 1 ? ShellBarMetrics.hiddenHeight : shown;
    // The button's seat, measured from the box's bottom edge — which is
    // pinned to the safe-area inset and does not move. Shown it sits in
    // the notch at the bar's top edge; hidden it rests on the floor.
    // Thirty-two logical pixels, and the whole point is that they are
    // TRAVELLED rather than skipped.
    final buttonBottom =
        lerpDouble(shown - ShellBarMetrics.buttonDiameter, 0, t)!;
    // The surface CONTRACTS rather than sliding out from under the
    // button. Sliding is the cheap version and it reads as a drawer
    // leaving; contracting reads as the control changing shape around
    // the one part of it that stays.
    final surfaceFactor = (1 - t).clamp(0.0, 1.0);
    // Labels go before the bar does, so it never reaches its last few
    // pixels still carrying legible text.
    final contentOpacity = shellBarContentOpacity(t);

    return SizedBox(
      height: boxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The tab surface, made inert once hidden so no tab can be
          // tapped or read through it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: surfaceFactor,
                child: Opacity(
                  opacity: contentOpacity,
                  child: IgnorePointer(
                    key: const ValueKey('shell-bar-surface'),
                    ignoring: hidden,
                    child: ExcludeSemantics(
                      key: const ValueKey('shell-bar-surface-semantics'),
                      excluding: hidden,
                      // A double-tap on the bar toggles it away. Scoped
                      // to the tab surface on purpose: the Reserve
                      // button is NOT a descendant, so the primary
                      // action keeps its zero-delay tap (see
                      // [ShellBarDoubleTap] for the 300 ms arena hold
                      // this avoids).
                      child: ShellBarDoubleTap(
                        onDoubleTap: () => unawaited(_setHidden(ref, !hidden)),
                        child: bar,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Introduce the gesture once, over the bar it acts on.
          if (showCoach)
            ShellSwipeCoachMark(
              barHeight: ShellBarMetrics.barHeightOf(context),
              onDismiss: () => unawaited(
                ref.read(shellSwipeCoachSeenProvider.notifier).markSeen(),
              ),
            ),
          // The raised Reserve action. Horizontally centred and
          // vertically CONTINUOUS — this is the anchor the eye follows
          // through the whole transition, and the one piece of chrome
          // still on screen once the bar has gone.
          Positioned(
            left: 0,
            right: 0,
            bottom: buttonBottom,
            child: Align(
              child: ShellCenterButton(
                label: reserveLabel,
                selected: reserveSelected,
                onPressed: onReservePressed,
                collapseProgress: t,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int index) => ShellBarTab(
        destination: destinations[index],
        selected: index == selectedIndex,
        onTap: () => onDestinationSelected(index),
      );
}

/// A flat side tab — icon over label, primary-tinted when selected.
///
/// Public so structural tests can locate a destination by its
/// [ShellDestination.label].
class ShellBarTab extends StatelessWidget {
  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const ShellBarTab({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme.merge(
              data: IconThemeData(
                color: color,
                size: ShellBarMetrics.tabIconSize,
              ),
              child: selected ? destination.selectedIcon : destination.icon,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (theme.textTheme.labelMedium ?? const TextStyle())
                  .copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
