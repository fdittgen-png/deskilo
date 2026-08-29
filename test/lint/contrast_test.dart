// SPDX-License-Identifier: 0BSD
//
// #721 — every text-on-surface pair the app relies on reaches WCAG 2.1
// AA (4.5:1) in the light, dark and warm schemes, and every decorative
// pair (outlines, icons on surfaces) reaches 3:1. Measured, not eyeballed:
// a scheme tweak that drops a pair below the floor fails here, before a
// member finds grey-on-grey on a sunny terrace or dark-on-dark at night.
import 'dart:math' as math;

import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG contrast ratio of [fg] on [bg], [fg] composited onto [bg] first
/// so a translucent foreground is judged as it renders.
double contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg);
  final l1 = _lum(f), l2 = _lum(bg);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final schemes = <String, ThemeData>{
    'light': DeskiloTheme.light(),
    'dark': DeskiloTheme.dark(),
    'warm': DeskiloTheme.warm(),
  };

  for (final entry in schemes.entries) {
    final name = entry.key;
    final theme = entry.value;
    final cs = theme.colorScheme;
    final b = theme.brightness;

    test('$name: body text on every surface reaches 4.5:1', () {
      final surfaces = {
        'surface': cs.surface,
        'surfaceContainerLow': cs.surfaceContainerLow,
        'surfaceContainer': cs.surfaceContainer,
        'surfaceContainerHigh': cs.surfaceContainerHigh,
        'surfaceContainerHighest': cs.surfaceContainerHighest,
        'scaffold': theme.scaffoldBackgroundColor,
        'card': theme.cardColor,
      };
      for (final s in surfaces.entries) {
        expect(contrast(cs.onSurface, s.value), greaterThanOrEqualTo(4.5),
            reason: '$name onSurface on ${s.key}');
        // Secondary text: subtitles, timestamps, hints — read as often
        // as titles, so the same floor.
        expect(contrast(cs.onSurfaceVariant, s.value), greaterThanOrEqualTo(4.5),
            reason: '$name onSurfaceVariant on ${s.key}');
        // Coloured text on surfaces: primary links/amounts, error text.
        expect(contrast(cs.primary, s.value), greaterThanOrEqualTo(4.5),
            reason: '$name primary text on ${s.key}');
        expect(contrast(cs.error, s.value), greaterThanOrEqualTo(4.5),
            reason: '$name error text on ${s.key}');
        // Amounts in the green of "paid" (calendar rows, account card).
        expect(contrast(AppStatusColors.successTextOf(b), s.value),
            greaterThanOrEqualTo(4.5),
            reason: '$name success text on ${s.key}');
        // The fill/dot green: a UI component, 3:1.
        expect(contrast(AppStatusColors.successOf(b), s.value),
            greaterThanOrEqualTo(3.0),
            reason: '$name success fill on ${s.key}');
        // Outlines and icons: the 3:1 floor for non-text.
        expect(contrast(cs.outline, s.value), greaterThanOrEqualTo(3.0),
            reason: '$name outline on ${s.key}');
      }
    });

    test('$name: text on filled components reaches 4.5:1', () {
      expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5),
          reason: '$name onPrimary on primary (filled buttons, owner chip)');
      expect(contrast(cs.onSecondaryContainer, cs.secondaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$name onSecondaryContainer (selected chips, segments)');
      expect(contrast(cs.onPrimaryContainer, cs.primaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$name onPrimaryContainer (help hint card)');
      expect(contrast(cs.onError, cs.error), greaterThanOrEqualTo(4.5),
          reason: '$name onError on error');
      expect(contrast(cs.onErrorContainer, cs.errorContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$name onErrorContainer');
      expect(
          contrast(AppStatusColors.onSuccessOf(b), AppStatusColors.successOf(b)),
          greaterThanOrEqualTo(4.5),
          reason: '$name onSuccess on success (checked-in chip)');
      expect(contrast(cs.onInverseSurface, cs.inverseSurface),
          greaterThanOrEqualTo(4.5),
          reason: '$name snackbar text');
    });
  }
}
