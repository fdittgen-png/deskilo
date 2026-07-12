// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// Semantic outcome colors (#196) — the theme-adjacent token for
/// "validated / accepted" states, mirroring the light/dark derivation of
/// `SeatStateColors`. The refusal side needs no token: it always uses the
/// theme's `colorScheme.error`.
///
/// Shades were picked for contrast on DesKilo's surfaces (FlexColorScheme
/// warm near-white light / blended dark, spec §14):
///  - light: Material green 800 (#2E7D32) — ≥4.5:1 on white-ish surfaces,
///    so it also carries button label text, not just icons;
///  - dark: Material green 300 (#81C784) — a lighter tint, ≥7:1 on the
///    blended dark surfaces (same tinting move as `SeatStateColors.*Dark`).
///
/// State is never conveyed by color alone (spec §11): every green/red use
/// pairs the color with a check/cross icon or an explicit label.
abstract final class AppStatusColors {
  /// Validated/accepted on light surfaces (Material green 800).
  static const Color success = Color(0xFF2E7D32);

  /// Lighter success tint for dark surfaces (Material green 300).
  static const Color successDark = Color(0xFF81C784);

  /// Foreground on a success-filled control, light theme.
  static const Color onSuccess = Colors.white;

  /// Foreground on a success-filled control, dark theme (very dark green,
  /// ~7:1 on [successDark]).
  static const Color onSuccessDark = Color(0xFF0D2B10);

  static Color successOf(Brightness brightness) =>
      brightness == Brightness.dark ? successDark : success;

  static Color onSuccessOf(Brightness brightness) =>
      brightness == Brightness.dark ? onSuccessDark : onSuccess;
}
