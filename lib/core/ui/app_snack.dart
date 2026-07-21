// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

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

  /// A saved/booked/copied confirmation.
  static void success(
    BuildContext context,
    String text, {
    bool replace = false,
  }) {
    final brightness = Theme.of(context).brightness;
    _show(
      context,
      text,
      background: AppStatusColors.successOf(brightness),
      foreground: AppStatusColors.onSuccessOf(brightness),
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
    required bool replace,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    // `replace` keeps the pre-#209 `clearSnackBars` pattern of rapid-fire
    // sites (seat taps, placement refusals): the newest message wins
    // instead of queuing.
    if (replace) messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        content: Text(
          text,
          style: foreground == null ? null : TextStyle(color: foreground),
        ),
      ),
    );
  }
}
