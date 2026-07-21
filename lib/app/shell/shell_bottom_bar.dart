// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import 'notched_bar_border.dart';

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

/// Sparkilo-style notched bottom navigation bar (#207).
///
/// The app's core action — Reserve — is a raised, primary-tinted circular
/// button docked into a concave notch carved into the bar's top edge; the
/// branch destinations are flat tabs flanking it, split around the centre
/// gap by index halving (4 tabs -> 2+2, 3 -> 2+1, 2 -> 1+1).
class ShellBottomBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  for (var i = leftCount; i < destinations.length; i++)
                    Expanded(child: _tab(i)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Clamp text scaling so labels grow with the OS setting but never
    // past what the fixed-height bar can show.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: ShellBarMetrics.barHeight + ShellBarMetrics.rise,
          child: Stack(
            children: [
              // Coloured bar pinned to the bottom. The top `rise` strip is
              // where the docked centre button protrudes above the notch.
              Positioned(left: 0, right: 0, bottom: 0, child: bar),
              // Raised Reserve action, horizontally centred over the notch.
              Align(
                alignment: Alignment.topCenter,
                child: _ReserveButton(
                  label: reserveLabel,
                  selected: reserveSelected,
                  onPressed: onReservePressed,
                ),
              ),
            ],
          ),
        ),
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

/// The raised, primary-tinted circular Reserve button.
///
/// Docks into the concave notch painted by the bar's [NotchedBarBorder]
/// shape — the notch IS the seat. Three layers of depth, all derived from
/// the theme (Sparkilo pattern):
///   * a hairline surface-coloured ring in the CircleBorder side — a crisp
///     seat separating the button from whatever scrolls beneath the notch;
///   * a top-light vertical gradient over the primary fill (painted by an
///     Ink so the ripple stays above it) — the dome that makes the disc
///     read as raised;
///   * a soft primary-tinted glow under the Material's own key shadow.
class _ReserveButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// The hub is the loaded form: filled seat icon + selected semantics —
  /// the centre button doubles as the bar's selection indicator.
  final bool selected;

  const _ReserveButton({
    required this.label,
    required this.onPressed,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.primary;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(buttonColor, Colors.white, 0.22)!,
        buttonColor,
        Color.lerp(buttonColor, Colors.black, 0.14)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: buttonColor,
        shape: CircleBorder(
          side: BorderSide(
            color: theme.colorScheme.surface,
            width: ShellBarMetrics.buttonRingWidth,
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: ShellBarMetrics.buttonDiameter,
              height: ShellBarMetrics.buttonDiameter,
              child: Center(
                child: Icon(
                  selected ? Icons.event_seat : Icons.event_seat_outlined,
                  size: ShellBarMetrics.buttonIconSize,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Tooltip(message: label, child: button),
    );
  }
}
