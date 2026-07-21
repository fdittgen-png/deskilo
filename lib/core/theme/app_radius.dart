// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';

/// Canonical corner-radius tokens (spec §14, identical to Sparkilo).
///
/// Never use an inline `BorderRadius.circular(n)` — pick a token
/// (lint-enforced by test/lint/no_inline_border_radius_test.dart).
abstract final class AppRadius {
  /// Small chips, indicators.
  static const double sm = 4;

  /// Buttons inside dense layouts.
  static const double md = 8;

  /// The canonical card / input / button radius.
  static const double lg = 12;

  /// Dialogs, bottom sheets, chips.
  static const double xl = 16;

  /// Hero surfaces.
  static const double xxl = 24;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
}
