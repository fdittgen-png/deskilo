// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';

/// Canonical motion durations of the feedback & motion pass (#209).
///
/// One token per animation intent — never an inline
/// `Duration(milliseconds: n)` at a call site.
abstract final class AppMotion {
  /// Cross-fade of a top-level view toggle (plan list/canvas, calendar
  /// list/timeline, Reserve hub Plan/Day/Week) via [AnimatedSwitcher].
  static const Duration viewSwitch = Duration(milliseconds: 200);

  /// Fade-in of `LoadingView`'s spinner: quick loads finish inside the
  /// fade and never flash a progress indicator.
  static const Duration loadingFadeIn = Duration(milliseconds: 200);
}
