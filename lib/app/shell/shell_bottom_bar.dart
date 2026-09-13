// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import 'notched_bar_border.dart';
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
class ShellBottomBar extends ConsumerStatefulWidget {
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

  @override
  ConsumerState<ShellBottomBar> createState() => _ShellBottomBarState();
}

class _ShellBottomBarState extends ConsumerState<ShellBottomBar> {
  /// Whether the stored preference has ever resolved.
  ///
  /// It is read asynchronously, so the first frame of a launch always
  /// says "shown". For somebody who chose the full-screen view that
  /// would play the hide animation on every single launch — the bar
  /// sliding away unasked, every morning. The first transition is
  /// therefore instant and only later ones animate.
  bool _settled = false;

  Future<void> _setHidden(bool hidden) async {
    await ref.read(shellBarHiddenProvider.notifier).set(hidden);
    // Performing the gesture is the best possible proof it was learned.
    await ref.read(shellSwipeCoachSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hiddenAsync = ref.watch(shellBarHiddenProvider);
    final hidden = hiddenAsync.value ?? false;
    final settled = _settled;
    if (!settled && hiddenAsync.hasValue) {
      // Rebuilt anyway by the watch above; flip the flag for next time
      // without asking for another frame.
      _settled = true;
    }
    // A hint can only appear once the flag it is gated on has resolved,
    // and never while the bar is already hidden: the gesture has plainly
    // been found.
    final coachSeen = ref.watch(shellSwipeCoachSeenProvider).value ?? true;
    final showCoach = !hidden && !coachSeen;

    // Tabs left of the centre gap: ceil-half of the destinations, so an
    // odd count keeps the heavier side leading (3 -> 2+1).
    final leftCount = (widget.destinations.length + 1) ~/ 2;

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
        height: ShellBarMetrics.barHeight,
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
                  for (var i = leftCount; i < widget.destinations.length; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final motion = settled
        ? motionDuration(context, kShellBarHideDuration)
        : Duration.zero;

    final stack = Stack(
      children: [
        // The tab surface: slid fully below the fold when hidden and made
        // inert, so no tab can be tapped or read through it.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _maybeSlide(
            hidden: hidden,
            motion: motion,
            child: IgnorePointer(
              key: const ValueKey('shell-bar-surface'),
              ignoring: hidden,
              child: ExcludeSemantics(
                key: const ValueKey('shell-bar-surface-semantics'),
                excluding: hidden,
                // A double-tap on the bar toggles it away. Scoped to the
                // tab surface on purpose: the Reserve button is NOT a
                // descendant, so the primary action keeps its zero-delay
                // tap (see [ShellBarDoubleTap] for the 300 ms arena hold
                // this avoids).
                child: ShellBarDoubleTap(
                  onDoubleTap: () => unawaited(_setHidden(!hidden)),
                  child: bar,
                ),
              ),
            ),
          ),
        ),
        // Introduce the gesture once, over the bar it acts on.
        if (showCoach)
          ShellSwipeCoachMark(
            barHeight: ShellBarMetrics.barHeight,
            onDismiss: () => unawaited(
              ref.read(shellSwipeCoachSeenProvider.notifier).markSeen(),
            ),
          ),
        // Raised Reserve action. It stays put when the bar leaves — the
        // one piece of chrome still on screen, and the way back.
        Align(
          alignment: hidden ? Alignment.bottomCenter : Alignment.topCenter,
          child: ShellCenterButton(
            label: widget.reserveLabel,
            selected: widget.reserveSelected,
            onPressed: widget.onReservePressed,
          ),
        ),
      ],
    );

    // Clamp text scaling so labels grow with the OS setting but never
    // past what the fixed-height bar can show.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          // A DRAG toggles; tap keeps its current meaning, so nothing
          // anybody does today changes. Down hides, up shows, and the
          // target is the bar's full width, not a 56 dp circle.
          //
          // A drag recognizer competes for the pointer but never HOLDS
          // the arena, so a plain tap on a tab or on the Reserve button
          // still resolves the instant the finger leaves. The double-tap
          // deliberately does not live here — see [ShellBarDoubleTap].
          onVerticalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v.abs() < kShellBarSwipeVelocity) return;
            unawaited(_setHidden(v > 0));
          },
          child: _maybeResize(
            motion: motion,
            child: SizedBox(
              height: hidden
                  ? ShellBarMetrics.hiddenHeight
                  : ShellBarMetrics.shownHeight,
              child: stack,
            ),
          ),
        ),
      ),
    );
  }

  /// [AnimatedSize] asserts on a zero duration, so the wrapper is
  /// skipped outright when motion is off or the preference has not
  /// settled yet.
  Widget _maybeResize({required Duration motion, required Widget child}) =>
      motion == Duration.zero
          ? child
          : AnimatedSize(
              duration: motion,
              curve: MotionTokens.ease,
              alignment: Alignment.bottomCenter,
              child: child,
            );

  Widget _maybeSlide({
    required bool hidden,
    required Duration motion,
    required Widget child,
  }) {
    final offset = Offset(0, hidden ? 1 : 0);
    return motion == Duration.zero
        ? Transform.translate(
            offset: Offset(0, hidden ? ShellBarMetrics.barHeight : 0),
            child: child,
          )
        : AnimatedSlide(
            offset: offset,
            duration: motion,
            curve: MotionTokens.ease,
            child: child,
          );
  }

  Widget _tab(int index) => ShellBarTab(
        destination: widget.destinations[index],
        selected: index == widget.selectedIndex,
        onTap: () => widget.onDestinationSelected(index),
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
