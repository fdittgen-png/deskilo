// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3602 (desk F1) — the one definition of window size. The posture of the
// window (phone, tablet, desk) comes from here; the fit of content comes from
// named local constraints beside their widget (`// content-fit: <why>`).
// `test/lint/window_class_test.dart` refuses any other comparison of a
// window's width with a number.
import 'package:flutter/widgets.dart';

/// The window's size class, by its width in logical pixels.
enum WindowClass {
  /// Below [medium]: a phone held upright.
  compact,

  /// From 600: a large phone on its side, a small tablet.
  medium,

  /// From 840: a tablet on its side, a narrow desktop window — the
  /// workspace's navigation appears beside the content.
  expanded,

  /// From 1200: a desktop window — the full sidebar.
  large,

  /// From 1600: a wide desktop window.
  extraLarge;

  /// The first width of each class, in logical pixels: defined once.
  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;
  static const double largeMinWidth = 1200;
  static const double extraLargeMinWidth = 1600;

  /// The class of [width], for a pane that decides by the room it gets
  /// (a `LayoutBuilder`'s constraints).
  static WindowClass ofWidth(double width) => switch (width) {
    >= extraLargeMinWidth => extraLarge,
    >= largeMinWidth => large,
    >= expandedMinWidth => expanded,
    >= mediumMinWidth => medium,
    _ => compact,
  };

  /// The class of the WINDOW [context] is shown in: its physical size over
  /// its pixel ratio, read from the view, so a framed `MediaQuery` (the
  /// app's reading frame) does not change the answer.
  static WindowClass of(BuildContext context) {
    final view = View.of(context);
    return ofWidth(view.physicalSize.width / view.devicePixelRatio);
  }

  /// Whether this class is [other] or wider.
  bool atLeast(WindowClass other) => index >= other.index;
}
