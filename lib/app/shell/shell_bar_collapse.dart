// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/motion.dart';
import 'shell_bar_visibility.dart';

/// Past this much of the pull, releasing settles collapsed.
///
/// One threshold, not two. Hysteresis exists to stop a control
/// oscillating around its midpoint, and a control with no intermediate
/// resting state cannot oscillate: it always settles at 0 or 1. A second
/// number here would be a knob nobody could defend.
const double kShellBarSettleThreshold = 0.45;

/// Where a released drag settles: 1 collapsed, 0 expanded.
///
/// A rule, not a gesture, so it is testable without one — and it needs
/// to be. Constructing a case where velocity and position genuinely
/// disagree through a real drag is not possible in a widget test:
/// Flutter's own velocity estimator fits over roughly the last 100 ms
/// and reports `Velocity.zero` for anything under 50 px/s, so a pull
/// followed by a fast reversal cancels out and arrives here as a
/// standing start. The behaviour is real on a device; the test for it
/// belongs here.
///
/// [velocity] is positive downward, matching [DragEndDetails].
double shellBarSettleTarget({
  required double progress,
  required double velocity,
}) {
  // A decisive flick means what it says even from a standing start,
  // which is the gesture #1173 shipped and people already have.
  if (velocity.abs() >= kShellBarSwipeVelocity) return velocity > 0 ? 1 : 0;
  return progress >= kShellBarSettleThreshold ? 1 : 0;
}

/// Owns the bar's collapse progress and the gesture that drives it.
///
/// Ported from the Sparkilo shell, which reimplemented its own bar as one
/// adaptive control after shipping the swipe-away view this app took in
/// #1173. What #1173 lacked was physical continuity: the bar left and a
/// button arrived, rather than one control changing shape.
///
/// One value, `t` ∈ [0, 1] — 0 expanded, 1 collapsed — handed to
/// [builder]. Every property of the bar is a function of it, so they
/// cannot drift apart the way a set of independent implicit animations
/// could. Before this there were three of them — an `AnimatedSize`, an
/// `AnimatedSlide` and a plain `Align` — and the `Align` was not
/// animated at all.
///
/// ## Progress is transient; the preference is not
///
/// [ShellBarHidden] stays exactly what it was: the SETTLED, persisted
/// choice, and what the three non-gesture ways back still set. The
/// controller here is the live, per-frame value and is deliberately not
/// persisted — putting a 60 fps number into shared preferences would be
/// writing to disk for the length of every swipe.
///
/// The two are kept in step in one direction each: a settle writes the
/// preference, and a controller that disagrees with the preference
/// animates to meet it — which covers the long-press, the double-tap and
/// the semantics action. A drag in flight ignores all of it, so the
/// finger always wins.
class ShellBarCollapse extends ConsumerStatefulWidget {
  const ShellBarCollapse({
    super.key,
    required this.dragExtent,
    required this.builder,
  });

  /// How far the finger must travel to cover the whole collapse. The
  /// bar's own height: the control moves with the gesture at roughly
  /// life size, which is what makes it feel pulled rather than triggered.
  final double dragExtent;

  final Widget Function(BuildContext context, double t) builder;

  @override
  ConsumerState<ShellBarCollapse> createState() => _ShellBarCollapseState();
}

class _ShellBarCollapseState extends ConsumerState<ShellBarCollapse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kShellBarHideDuration,
  );

  /// True between drag start and drag end. While it is set, an external
  /// change to the preference must not yank the bar out from under the
  /// finger.
  bool _dragging = false;

  /// Whether the stored preference has ever resolved.
  ///
  /// It is read asynchronously, so the first frame of a launch always
  /// says "shown". For somebody who chose the full-screen view that
  /// would play the collapse on every single launch — the bar sliding
  /// away unasked, every morning. The first transition therefore lands
  /// instantly and only later ones animate.
  bool _resolved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Moves to [target], instantly when motion is off or the preference
  /// has only just arrived.
  ///
  /// `motionDuration` is the one seam that decides whether anything in
  /// this app animates (#611), and an [AnimationController] must ask it
  /// like everything else — a reduced-motion user gets the end state,
  /// not a faster version of the journey.
  void _settle(double target, {required bool animate}) {
    final motion =
        animate ? motionDuration(context, kShellBarHideDuration) : Duration.zero;
    if (motion == Duration.zero) {
      _controller.stop();
      _controller.value = target;
      return;
    }
    unawaited(_controller.animateTo(
      target,
      duration: motion,
      curve: MotionTokens.ease,
    ));
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    // Downward is collapse, so a positive delta increases progress. The
    // clamp is what makes over-pulling a no-op rather than a rubber
    // band: there is nothing past collapsed to reveal.
    _controller.value =
        (_controller.value + delta / widget.dragExtent).clamp(0.0, 1.0);
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    _dragging = false;
    final target = shellBarSettleTarget(
      progress: _controller.value,
      velocity: details.primaryVelocity ?? 0,
    );
    _settle(target, animate: true);

    final hidden = target == 1;
    if ((ref.read(shellBarHiddenProvider).value ?? false) != hidden) {
      await ref.read(shellBarHiddenProvider.notifier).set(hidden);
    }
    // Performing the gesture is the best possible proof it was learned.
    await ref.read(shellSwipeCoachSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shellBarHiddenProvider);
    final target = (async.value ?? false) ? 1.0 : 0.0;
    final firstResolution = !_resolved && async.hasValue;
    if (firstResolution) _resolved = true;

    if (!_dragging && !_controller.isAnimating && _controller.value != target) {
      // Safe during build, and deliberately not deferred to a post-frame
      // callback: `animateTo` only starts a ticker — it does not touch
      // `value`, so no listener is notified inside this build. Deferring
      // instead costs the externally-triggered paths (the long-press,
      // the double-tap, the semantics action) one frame of dead time
      // before anything moves, which is the difference between
      // "responds" and "hesitates".
      _settle(target, animate: !firstResolution);
    }

    return GestureDetector(
      // A DRAG collapses; tap keeps its current meaning, so nothing
      // anybody does today changes. Down hides, up shows, and the target
      // is the bar's full width, not a 56 dp circle.
      //
      // A drag recognizer competes for the pointer but never HOLDS the
      // arena until the finger has actually moved past the slop, so a
      // plain tap on a tab or on the Reserve button still resolves the
      // instant the finger leaves. The double-tap deliberately does not
      // live here — see [ShellBarDoubleTap].
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: (details) => unawaited(_onDragEnd(details)),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, _controller.value),
      ),
    );
  }
}
