// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

/// The five floor-plan seat states (spec §4.1).
enum SeatState { free, reserved, occupied, mine, blocked }

/// Muted, colorblind-aware accent palette for seat states — the DesKilo
/// analog of Sparkilo's fuel-color palette (spec §14).
///
/// State is NEVER conveyed by color alone: the floor plan pairs each state
/// with an icon/pattern (accessibility requirement, spec §11). Hues sit on
/// the blue↔orange axis plus lightness contrast so the palette stays legible
/// under deuteranopia/protanopia.
abstract final class SeatStateColors {
  static const Color free = Color(0xFF4F7C44);
  static const Color reserved = Color(0xFF3B6FA0);
  static const Color occupied = Color(0xFFBE7C1E);
  static const Color mine = Color(0xFFC2410C);
  static const Color blocked = Color(0xFF6B7280);

  /// Lighter tints for dark surfaces.
  static const Color freeDark = Color(0xFF8BC34A);
  static const Color reservedDark = Color(0xFF7FB2E5);
  static const Color occupiedDark = Color(0xFFE8B04E);
  static const Color mineDark = Color(0xFFFF8A50);
  static const Color blockedDark = Color(0xFF9CA3AF);

  static Color of(SeatState state, {required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    return switch (state) {
      SeatState.free => dark ? freeDark : free,
      SeatState.reserved => dark ? reservedDark : reserved,
      SeatState.occupied => dark ? occupiedDark : occupied,
      SeatState.mine => dark ? mineDark : mine,
      SeatState.blocked => dark ? blockedDark : blocked,
    };
  }
}
