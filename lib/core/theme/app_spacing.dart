// SPDX-License-Identifier: MIT
import 'package:flutter/widgets.dart';

/// Canonical spacing tokens (#210) — the padding/gap analog of [AppRadius].
///
/// Pick a token instead of writing a raw `EdgeInsets` literal wherever the
/// value maps cleanly (4→xs, 8→sm, 12→md, 16→lg, 24→xl). Screen-level
/// bodies and ListViews use [screenGutter]; modal edit sheets use [xl].
/// Pinned by test/core/theme/app_spacing_test.dart.
abstract final class AppSpacing {
  /// Hairline gaps: chip spacing inside a row, icon-to-text micro gaps.
  static const double xs = 4;

  /// Small gaps: within-group element spacing.
  static const double sm = 8;

  /// Medium gaps: compact list gutters, card padding.
  static const double md = 12;

  /// The canonical screen gutter and between-group spacing.
  static const double lg = 16;

  /// Hero spacing: modal sheet gutters, empty-state padding.
  static const double xl = 24;

  /// Horizontal gutter of screen-level bodies and ListViews.
  static const double screenGutter = lg;

  // Ready-made EdgeInsets so call sites stay `const` one-liners.
  static const EdgeInsets gutterAll = EdgeInsets.all(screenGutter);
  static const EdgeInsets gutterH =
      EdgeInsets.symmetric(horizontal: screenGutter);

  static const EdgeInsets xsAll = EdgeInsets.all(xs);
  static const EdgeInsets smAll = EdgeInsets.all(sm);
  static const EdgeInsets mdAll = EdgeInsets.all(md);
  static const EdgeInsets lgAll = EdgeInsets.all(lg);
  static const EdgeInsets xlAll = EdgeInsets.all(xl);

  static const EdgeInsets xsH = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets smH = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets mdH = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets lgH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets xlH = EdgeInsets.symmetric(horizontal: xl);
}
