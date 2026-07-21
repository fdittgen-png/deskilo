// SPDX-License-Identifier: 0BSD
//
// #210: WCAG contrast regression guard for the seat-state palette. The
// floor-plan painter draws occupant labels in `onSurface` over a seat
// fill of the state color at 45% alpha on the desk fill
// (`surfaceContainerHighest`) — see floor_plan_painter.dart. The day
// timeline draws occupant labels in white/black87 (picked via
// `ThemeData.estimateBrightnessForColor`) over the SOLID state color —
// see day_timeline.dart `_block`. Both label styles must keep a WCAG
// ratio of at least 3.0 over their fill in every app theme; audited
// 2026-07 (worst case: light `occupied` timeline block at ~3.4).
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Alpha the painter applies to a live seat's state fill — keep in sync
/// with floor_plan_painter.dart (`accent.withValues(alpha: ... 0.45)`).
const double painterSeatFillAlpha = 0.45;

/// Minimum ratio for the seat labels (WCAG 1.4.11 non-text / large-text
/// threshold — the labels are short, bold-rendered 11px canvas strings).
const double minRatio = 3.0;

void main() {
  final themes = <String, ThemeData>{
    'light': DeskiloTheme.light(),
    'dark': DeskiloTheme.dark(),
    'warm': DeskiloTheme.warm(),
  };

  group('floor-plan painter labels (onSurface over 45% state fill)', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      test('$name theme: every state fill keeps >= $minRatio', () {
        final scheme = theme.colorScheme;
        for (final state in SeatState.values) {
          final accent = SeatStateColors.of(
            state,
            brightness: scheme.brightness,
          );
          // The painter composites the translucent state fill onto the
          // desk rectangle (surfaceContainerHighest).
          final fill = Color.alphaBlend(
            accent.withValues(alpha: painterSeatFillAlpha),
            scheme.surfaceContainerHighest,
          );
          final ratio = contrastRatio(scheme.onSurface, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(minRatio),
            reason: '$state label (onSurface over 45% fill) in $name '
                'theme: ${ratio.toStringAsFixed(2)} < $minRatio',
          );
        }
      });
    }
  });

  group('day-timeline block labels (auto on-color over solid state)', () {
    for (final brightness in Brightness.values) {
      test('$brightness: every state keeps >= $minRatio', () {
        for (final state in SeatState.values) {
          final fill = SeatStateColors.of(state, brightness: brightness);
          // Same pick as day_timeline.dart `_block`.
          final onColor =
              ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
                  ? Colors.white
                  : Colors.black87;
          // black87 is translucent — composite it like the screen does.
          final effective = Color.alphaBlend(onColor, fill);
          final ratio = contrastRatio(effective, fill);
          expect(
            ratio,
            greaterThanOrEqualTo(minRatio),
            reason: '$state block label ($brightness): '
                '${ratio.toStringAsFixed(2)} < $minRatio',
          );
        }
      });
    }
  });
}
