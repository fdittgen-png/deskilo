// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// The motion core of the app-wide motion pass (#611).
///
/// One seam decides whether ANYTHING animates: the workspace
/// `uiAnimations` feature flag (installed here by the app shell via
/// [MotionSettings] — core must not import feature providers) AND the
/// platform's reduced-motion setting (`MediaQuery.disableAnimations`).
/// Every animated surface asks [motionDuration] instead of re-deciding;
/// when motion is off the duration collapses to [Duration.zero] and the
/// change lands instantly.
///
/// Durations/curves follow the Material 3 motion spec: 150–400 ms,
/// standard easing for in-place changes, emphasized easing for larger
/// spatial changes. No idle loops — every animation here is finite so
/// `pumpAndSettle` always settles.
abstract final class MotionTokens {
  /// Small in-place feedback: badge counts, icon swaps.
  static const Duration quick = Duration(milliseconds: 150);

  /// The workhorse: state-colour changes, reveals, view cross-fades.
  static const Duration standard = Duration(milliseconds: 250);

  /// Larger spatial changes: month slides, canvas zoom-to-target.
  static const Duration emphasized = Duration(milliseconds: 350);

  /// Material 3 standard easing — in-place transitions.
  static const Curve ease = Easing.standard;

  /// Material 3 emphasized-decelerate — elements entering the screen.
  static const Curve enter = Easing.emphasizedDecelerate;
}

/// Inherited switch for the `uiAnimations` workspace feature: the app
/// shell installs the flag's value above the navigator so widgets read
/// it without each re-watching the provider. Absent (plain widget
/// tests) the flag counts as ON — its registry default.
class MotionSettings extends InheritedWidget {
  const MotionSettings({
    required this.animationsEnabled,
    required super.child,
    super.key,
  });

  /// The `uiAnimations` feature flag value.
  final bool animationsEnabled;

  /// Whether motion is on HERE: the flag AND the platform's
  /// reduced-motion setting must both allow it.
  static bool enabledOf(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<MotionSettings>();
    return (settings?.animationsEnabled ?? true) &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }

  @override
  bool updateShouldNotify(MotionSettings oldWidget) =>
      oldWidget.animationsEnabled != animationsEnabled;
}

/// [base] while motion is enabled, [Duration.zero] otherwise — the one
/// question every animated surface asks.
Duration motionDuration(BuildContext context, Duration base) =>
    MotionSettings.enabledOf(context) ? base : Duration.zero;

/// Animates the appearance/disappearance of an optional banner or card
/// (closed-day banner, help hint) instead of letting it pop: the size
/// eases open/closed and, when the child's identity changes (e.g.
/// banner ↔ nothing), the swap cross-fades. Wraps at the CALL SITE —
/// the child widget's internals stay untouched.
class MotionReveal extends StatelessWidget {
  const MotionReveal({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, MotionTokens.standard);
    // Motion off = no animated wrappers at all: AnimatedSize with a zero
    // duration would re-dirty itself during layout (framework assert).
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: MotionTokens.ease,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: MotionTokens.enter,
        switchOutCurve: MotionTokens.ease,
        child: child,
      ),
    );
  }
}

/// Fades its child back in whenever [changeKey] changes while KEEPING
/// the child subtree alive — the FadeIndexedStack pattern for the tab
/// shell: the branch stack must never be rebuilt or re-keyed (that
/// would drop the #111 per-tab keep-alive state), so the switch is a
/// finite fade-in of the whole stack instead of an [AnimatedSwitcher].
class FadeInOnChange extends StatefulWidget {
  const FadeInOnChange({
    required this.changeKey,
    required this.child,
    super.key,
  });

  /// Identity of the shown content (e.g. the branch index) — a change
  /// triggers one fade-in.
  final Object changeKey;

  final Widget child;

  @override
  State<FadeInOnChange> createState() => _FadeInOnChangeState();
}

class _FadeInOnChangeState extends State<FadeInOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: MotionTokens.standard,
  );

  @override
  void didUpdateWidget(FadeInOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.changeKey == oldWidget.changeKey) return;
    final duration = motionDuration(context, MotionTokens.standard);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.duration = duration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
          CurvedAnimation(parent: _controller, curve: MotionTokens.enter),
      child: widget.child,
    );
  }
}
