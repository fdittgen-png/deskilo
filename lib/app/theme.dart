// SPDX-License-Identifier: MIT
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_radius.dart';

/// DesKilo brand palette — muted burnt orange (spec §14, decided 2026-07-07).
///
/// Same design language as Sparkilo's forest green, own hue: sibling apps,
/// distinct identities. The teal tertiary deliberately quotes Sparkilo's
/// tertiary so the family resemblance shows in accents.
final FlexSchemeColor _burntOrange = FlexSchemeColor.from(
  primary: const Color(0xFFC2410C),
  primaryContainer: const Color(0xFFF4D8C4),
  secondary: const Color(0xFF8A5A33),
  secondaryContainer: const Color(0xFFEBDCC9),
  tertiary: const Color(0xFF3C6E63),
  tertiaryContainer: const Color(0xFFCFE3DC),
  appBarColor: const Color(0xFFEBDCC9),
  error: const Color(0xFFB3261E),
);

const FlexSubThemesData _subThemes = FlexSubThemesData(
  defaultRadius: AppRadius.lg,
  chipRadius: AppRadius.xl,
  dialogRadius: AppRadius.xl,
  bottomSheetRadius: AppRadius.xl,
  inputDecoratorBorderType: FlexInputBorderType.outline,
  inputDecoratorRadius: AppRadius.lg,
  snackBarRadius: AppRadius.lg,
);

/// The three DesKilo themes: [light], [dark], and the signature
/// orange-forward [warm] (the analog of Sparkilo's eco theme).
abstract final class DeskiloTheme {
  static ThemeData light() {
    return FlexThemeData.light(
      colors: _burntOrange,
      blendLevel: 8,
      subThemesData: _subThemes,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return FlexThemeData.dark(
      colors: _burntOrange.toDark(28),
      blendLevel: 22,
      subThemesData: _subThemes,
      useMaterial3: true,
    );
  }

  static ThemeData warm() {
    return FlexThemeData.light(
      colors: _burntOrange,
      blendLevel: 20,
      // custom pulls the scheme's appBarColor (the warm container tint).
      appBarStyle: FlexAppBarStyle.custom,
      subThemesData: _subThemes,
      useMaterial3: true,
    );
  }
}
