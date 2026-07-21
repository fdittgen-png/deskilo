// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// Soft, layered shadow tokens — the app's depth language. Two-layer
/// shadows (a tight contact shadow + a wider ambient one) read as
/// gently lifted rather than harshly dropped, which is what makes a
/// surface feel tactile and smooth rather than flat. Tuned per theme so
/// dark mode stays subtle instead of muddy.
abstract final class AppElevation {
  /// Resting cards, chips, list rows — barely lifted off the surface.
  static List<BoxShadow> low(Brightness brightness) =>
      brightness == Brightness.dark
          ? const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x0D1A1206),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x141A1206),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ];

  /// Raised sheets, the floor-plan seat tiles, the active view — clearly
  /// afloat above the room.
  static List<BoxShadow> medium(Brightness brightness) =>
      brightness == Brightness.dark
          ? const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0x141A1206),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: Color(0x1F1A1206),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ];
}
