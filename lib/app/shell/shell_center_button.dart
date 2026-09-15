// SPDX-License-Identifier: 0BSD
import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/events/providers/event_providers.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../../l10n/app_localizations.dart';
import 'shell_bar_visibility.dart';
import 'shell_bottom_bar.dart' show ShellBarMetrics;

/// The raised, primary-tinted circular Reserve button.
///
/// Docks into the concave notch painted by the bar's `NotchedBarBorder`
/// shape — the notch IS the seat. Three layers of depth, all derived
/// from the theme (the Sparkilo pattern):
///   * a hairline surface-coloured ring in the CircleBorder side — a
///     crisp seat separating the button from whatever scrolls beneath;
///   * a top-light vertical gradient over the primary fill (painted by
///     an Ink so the ripple stays above it) — the dome that makes the
///     disc read as raised;
///   * a soft primary-tinted glow under the Material's own key shadow.
///
/// Extracted from `ShellBottomBar` (#1173): this is where the
/// swipe-away feature's non-gesture escape hatch belongs, next to the
/// button that is the only chrome left on screen once the bar is gone.
class ShellCenterButton extends ConsumerWidget {
  const ShellCenterButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.selected,
    this.collapseProgress = 0,
  });

  /// Localized tooltip / semantic label.
  final String label;

  final VoidCallback onPressed;

  /// The hub is the loaded form: filled seat icon + selected semantics —
  /// the centre button doubles as the bar's selection indicator.
  final bool selected;

  /// How far the bar around this button has collapsed — 0 docked in the
  /// notch, 1 floating alone over the content.
  ///
  /// Only the DEPTH reads this. The button's size does not change: it is
  /// 56 dp, Material's standard FAB, and the primary action of the whole
  /// app — there is nowhere for it to shrink to that would not cost it
  /// prominence. What changes is what it is sitting on. Docked, it has a
  /// bar surface beneath it and a tight shadow is right; alone over a
  /// floor plan, a softer and wider one is what says "I am floating here
  /// now".
  final double collapseProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hidden = ref.watch(shellBarHiddenProvider).value ?? false;
    // #1322 — full screen takes the bell away with the title bar, so the
    // one piece of chrome left on screen carries its count: choosing more
    // room must never hide a decision somebody is waiting for. No count,
    // NO BADGE WIDGET — the #687 rule of the Messages destination.
    final eventsOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.eventsTab);
    final pendingCount = ref.watch(myPendingEventCountProvider).value ?? 0;
    final pending = hidden && eventsOn ? pendingCount : 0;
    // Clamped because the collapse is driven straight off a finger, and
    // a drag that overshoots must not produce a negative blur.
    final t = collapseProgress.clamp(0.0, 1.0);
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

    // Idempotent on purpose: the semantics action and the physical
    // long-press share one merged semantics node, so performing the
    // action invokes BOTH handlers. Setting an explicit target — rather
    // than toggling — makes the second call a no-op instead of undoing
    // the first.
    Future<void> toggleBar() async {
      await ref.read(shellBarHiddenProvider.notifier).set(!hidden);
      await ref.read(shellSwipeCoachSeenProvider.notifier).markSeen();
      if (!context.mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          hidden
              ? (l10n?.shellBarShownAnnounce ?? 'Navigation bar shown')
              : (l10n?.shellBarHiddenAnnounce ?? 'Navigation bar hidden'),
          Directionality.of(context),
        ),
      );
    }

    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary
                .withValues(alpha: lerpDouble(0.30, 0.20, t)!),
            blurRadius: lerpDouble(14, 22, t)!,
            offset: Offset(0, lerpDouble(4, 7, t)!),
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
        elevation: lerpDouble(4, 7, t)!,
        shadowColor:
            Colors.black.withValues(alpha: lerpDouble(0.4, 0.28, t)!),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            // The long-press MUST share this InkWell's arena. As an outer
            // GestureDetector it would compete with the tap for the same
            // pointer, and a finger resting a fraction too long would
            // toggle the bar while the reservation never opened — the
            // exact report Sparkilo's #4103 came from. One recognizer
            // set, disambiguated by Flutter, and the ripple matches the
            // gesture.
            onLongPress: () => unawaited(toggleBar()),
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
      label: pending == 0
          ? label
          : '$label, ${l10n?.shellPendingDecisions(pending) ?? '$pending awaiting your decision'}',
      button: true,
      selected: selected,
      // Exposed to TalkBack and switch access as an ACTION, so somebody
      // who cannot perform a drag can still bring a hidden bar back.
      hint: hidden
          ? (l10n?.shellBarShowHint ?? 'Long-press to show the navigation bar')
          : (l10n?.shellBarHideHint ?? 'Long-press for a full-screen view'),
      onLongPress: () => unawaited(toggleBar()),
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: pending == 0
            ? button
            : Badge.count(
                key: const ValueKey('shell-center-pending'),
                count: pending,
                child: button,
              ),
      ),
    );
  }
}
