// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';

import '../motion/motion.dart';

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

  /// The context-aware tokens (#402/#611): when the platform asks for
  /// reduced motion OR the workspace switched the `uiAnimations` feature
  /// off, every animation collapses to zero instead of each call site
  /// re-deciding — via the motion core's [motionDuration]. Use these
  /// anywhere a BuildContext exists; the consts above remain for the few
  /// context-free sites.
  static Duration viewSwitchOf(BuildContext context) =>
      motionDuration(context, viewSwitch);

  static Duration loadingFadeInOf(BuildContext context) =>
      motionDuration(context, loadingFadeIn);
}
