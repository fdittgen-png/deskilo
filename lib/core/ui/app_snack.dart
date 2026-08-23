// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/status_colors.dart';

/// Semantic snackbars (#209): every `showSnackBar` call site goes through
/// one of the three variants so outcome severity is visible at a glance.
///
///  - [error]: failures and refusals — `colorScheme.error` background;
///  - [success]: saved/booked/copied confirmations — the
///    [AppStatusColors.success] token (#196) with its on-color;
///  - [info]: neutral notices (occupied-by, closure info) — the theme's
///    default inverse-surface look.
///
/// All variants float (Material 3 recommendation) and keep the message as
/// a plain [Text] — tests keep asserting on the exact text. State is never
/// conveyed by color alone (spec §11): the message itself carries the
/// outcome; color only reinforces it.
abstract final class AppSnack {
  /// A failure or refusal.
  static void error(
    BuildContext context,
    String text, {
    bool replace = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      text,
      background: scheme.error,
      foreground: scheme.onError,
      replace: replace,
    );
  }

  /// A saved/booked/copied confirmation. #611 — the check scales in
  /// briefly (finite, settles), marking the success moment; instant
  /// under reduced motion / uiAnimations off.
  static void success(
    BuildContext context,
    String text, {
    bool replace = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final foreground = AppStatusColors.onSuccessOf(brightness);
    _show(
      context,
      text,
      background: AppStatusColors.successOf(brightness),
      foreground: foreground,
      leading: _ScaleInCheck(color: foreground),
      replace: replace,
    );
  }

  /// A neutral notice — theme default (inverse surface) look.
  static void info(
    BuildContext context,
    String text, {
    bool replace = false,
  }) {
    _show(context, text, replace: replace);
  }

  static void _show(
    BuildContext context,
    String text, {
    Color? background,
    Color? foreground,
    Widget? leading,
    required bool replace,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    // `replace` keeps the pre-#209 `clearSnackBars` pattern of rapid-fire
    // sites (seat taps, placement refusals): the newest message wins
    // instead of queuing.
    if (replace) messenger.clearSnackBars();
    // The message stays a plain [Text] — tests assert on the exact text.
    final message = Text(
      text,
      style: foreground == null ? null : TextStyle(color: foreground),
    );
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        content: leading == null
            ? message
            : Row(children: [
                leading,
                const SizedBox(width: 12),
                Expanded(child: message),
              ]),
      ),
    );
  }
}

/// The success check, scaling in with a slight overshoot (#611). A
/// one-shot [TweenAnimationBuilder]: finite by construction, and with
/// motion off the duration is zero — the icon is simply there.
class _ScaleInCheck extends StatelessWidget {
  const _ScaleInCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motionDuration(context, MotionTokens.standard),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Icon(Icons.check_circle_outline, color: color, size: 20),
    );
  }
}
