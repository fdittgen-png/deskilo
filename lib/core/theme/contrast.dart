// SPDX-License-Identifier: 0BSD
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.1 contrast, and the one operation the theme needs from it:
/// push a foreground's lightness away from its background until the
/// pair meets a floor (#721).
///
/// Computed, not hand-picked: the audit test measures the same pairs
/// this adjusts, so a future palette change cannot quietly land a
/// button whose label is unreadable in the dark scheme.
abstract final class Contrast {
  static double _lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  /// Ratio of [fg] on [bg], [fg] composited first.
  static double ratio(Color fg, Color bg) {
    final f = Color.alphaBlend(fg, bg);
    final l1 = _lum(f), l2 = _lum(bg);
    return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
  }

  /// [fg] moved in lightness, away from [bg], in 2% steps until
  /// [floor] is met — hue and saturation untouched, so a burnt-orange
  /// stays burnt orange, just deep enough to read. Returns [fg]
  /// unchanged when it already passes.
  static Color ensure(Color fg, Color bg, {double floor = 4.5}) {
    if (ratio(fg, bg) >= floor) return fg;
    // Toward whichever pole contrasts MORE with the background — white
    // on a mid orange tops out near 3:1, black on the same orange passes
    // 5:1, so "lighten because the background is darkish" is the wrong
    // rule for a saturated primary.
    final toBlack = ratio(Colors.black, bg) >= ratio(Colors.white, bg);
    var hsl = HSLColor.fromColor(fg);
    for (var i = 0; i < 50; i++) {
      final l = (hsl.lightness + (toBlack ? -0.02 : 0.02)).clamp(0.0, 1.0);
      hsl = hsl.withLightness(l);
      if (ratio(hsl.toColor(), bg) >= floor) break;
    }
    return hsl.toColor();
  }
}
