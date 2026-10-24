// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The personal layer's design tokens: what Me wears when it is the
// five-destination personal shell, and nothing a space or a printed report
// reads. One ThemeExtension for the semantic colours, one type scale mapped
// onto the TextTheme roles, one table of logical dimensions, and the pure
// classification of a window into sidebar / rail / bar / menu. The app's own
// font only; no clamp on the reader's text scale.
//
// Every pair below is measured, not hoped: test/core/theme/personal_theme_test
// runs the contrast audit over the derived ThemeData and the token pairs
// themselves (text 4.5:1, interactive borders 3:1).
import 'package:flutter/material.dart';

import '../navigation/navigation_style.dart' show kWideNavigationMaxTextScale;

/// The semantic colours of the personal layer, light and dark.
@immutable
class PersonalTheme extends ThemeExtension<PersonalTheme> {
  const PersonalTheme({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.text,
    required this.secondaryText,
    required this.primary,
    required this.onPrimary,
    required this.primaryTint,
    required this.decorativeBorder,
    required this.interactiveBorder,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
  });

  static const PersonalTheme light = PersonalTheme(
    canvas: Color(0xFFF5F7FB),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFEDF2F8),
    text: Color(0xFF17233B),
    secondaryText: Color(0xFF58677D),
    primary: Color(0xFF3454D1),
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFFEAF0FF),
    decorativeBorder: Color(0xFFDCE3ED),
    interactiveBorder: Color(0xFF79879A),
    success: Color(0xFF15715C),
    successTint: Color(0xFFE6F4EE),
    warning: Color(0xFF8A4B08),
    warningTint: Color(0xFFFFF3DF),
    danger: Color(0xFFB3263A),
    dangerTint: Color(0xFFFDECEF),
  );

  static const PersonalTheme dark = PersonalTheme(
    canvas: Color(0xFF101827),
    surface: Color(0xFF182336),
    subtle: Color(0xFF233047),
    text: Color(0xFFF0F4FC),
    secondaryText: Color(0xFFB5C2D5),
    primary: Color(0xFFAABEFF),
    onPrimary: Color(0xFF10204D),
    primaryTint: Color(0xFF253862),
    decorativeBorder: Color(0xFF34455E),
    interactiveBorder: Color(0xFF8798B1),
    success: Color(0xFF83DABC),
    successTint: Color(0xFF193C33),
    warning: Color(0xFFFFD08B),
    warningTint: Color(0xFF45331B),
    danger: Color(0xFFFFB1BD),
    dangerTint: Color(0xFF472735),
  );

  /// The page behind every card.
  final Color canvas;

  /// A card, a sheet, the header.
  final Color surface;

  /// A quieter surface: the sidebar, a selected row's neighbourhood.
  final Color subtle;
  final Color text;
  final Color secondaryText;
  final Color primary;
  final Color onPrimary;

  /// A selected destination, a highlighted row: primary as a wash.
  final Color primaryTint;

  /// A border that separates; never the only boundary of an input.
  final Color decorativeBorder;

  /// A border that marks an input or a control: 3:1 on every surface.
  final Color interactiveBorder;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;

  /// The tokens of [brightness].
  static PersonalTheme forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The personal tokens in scope, or the ones of the ambient brightness
  /// where the personal theme is not applied (the shell off).
  static PersonalTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PersonalTheme>() ?? forBrightness(theme.brightness);
  }

  /// `(foreground, background)` of every semantic pair a reader meets.
  List<(String, Color, Color)> get textPairs => [
        ('text on canvas', text, canvas),
        ('text on surface', text, surface),
        ('text on subtle', text, subtle),
        ('secondary text on canvas', secondaryText, canvas),
        ('secondary text on surface', secondaryText, surface),
        ('secondary text on subtle', secondaryText, subtle),
        ('primary on surface', primary, surface),
        ('primary on canvas', primary, canvas),
        ('primary on primary tint', primary, primaryTint),
        ('on primary on primary', onPrimary, primary),
        ('success on success tint', success, successTint),
        ('success on surface', success, surface),
        ('warning on warning tint', warning, warningTint),
        ('warning on surface', warning, surface),
        ('danger on danger tint', danger, dangerTint),
        ('danger on surface', danger, surface),
      ];

  /// The borders that must read as a boundary on every surface.
  List<(String, Color, Color)> get componentPairs => [
        ('interactive border on surface', interactiveBorder, surface),
        ('interactive border on canvas', interactiveBorder, canvas),
        ('interactive border on subtle', interactiveBorder, subtle),
      ];

  /// The table is normative and whole: no caller edits one colour of it,
  /// so the copy a ThemeExtension promises is the table itself.
  @override
  PersonalTheme copyWith() => this;

  @override
  PersonalTheme lerp(PersonalTheme? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return PersonalTheme(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      subtle: mix(subtle, other.subtle),
      text: mix(text, other.text),
      secondaryText: mix(secondaryText, other.secondaryText),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryTint: mix(primaryTint, other.primaryTint),
      decorativeBorder: mix(decorativeBorder, other.decorativeBorder),
      interactiveBorder: mix(interactiveBorder, other.interactiveBorder),
      success: mix(success, other.success),
      successTint: mix(successTint, other.successTint),
      warning: mix(warning, other.warning),
      warningTint: mix(warningTint, other.warningTint),
      danger: mix(danger, other.danger),
      dangerTint: mix(dangerTint, other.dangerTint),
    );
  }
}

/// The logical dimensions of the personal shell. Existing tokens
/// (AppSpacing, AppRadius) keep their values; these are the shell's own.
abstract final class PersonalShellMetrics {
  /// A window at least this wide keeps the destinations in a sidebar.
  static const double sidebarMinWidth = 1200;

  /// From here to [sidebarMinWidth] the destinations are a rail.
  static const double railMinWidth = 840;
  static const double sidebarWidth = 248;
  static const double railWidth = 80;

  /// The widest a page's content grows.
  static const double contentMaxWidth = 1280;
  static const double gutterExpanded = 32;
  static const double gutterMedium = 24;
  static const double gutterCompact = 16;

  /// The header with the destinations beside the content.
  static const double headerHeight = 72;

  /// The compact header: the web and Android, and the iPhone.
  static const double compactHeaderHeight = 64;
  static const double compactHeaderHeightCupertino = 56;

  /// The bottom bar's content, before the safe area: the web, Android, the
  /// iPhone.
  static const double barHeightWeb = 72;
  static const double barHeightAndroid = 80;
  static const double barHeightCupertino = 56;

  /// A compact window shorter than this (keyboard closed) has no room for
  /// a bar under the content: the destinations move into the menu.
  static const double menuMinHeight = 480;
  static const double cardRadius = 20;
  static const double controlRadius = 12;
  static const double minTarget = 48;

  static const BorderRadius cardRadiusAll =
      BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius controlRadiusAll =
      BorderRadius.all(Radius.circular(controlRadius));

  /// The header's height for [layout] on [platform].
  static double headerHeightFor(PersonalLayout layout, TargetPlatform platform) {
    if (layout == PersonalLayout.sidebar || layout == PersonalLayout.rail) {
      return headerHeight;
    }
    return _cupertino(platform)
        ? compactHeaderHeightCupertino
        : compactHeaderHeight;
  }

  /// The bottom bar's content height on [platform] ([web] first: mobile
  /// Safari is the web, not an iPhone scene).
  static double barHeightFor(TargetPlatform platform, {required bool web}) {
    if (web) return barHeightWeb;
    return _cupertino(platform) ? barHeightCupertino : barHeightAndroid;
  }

  /// The page gutter for [layout].
  static double gutterFor(PersonalLayout layout) => switch (layout) {
        PersonalLayout.sidebar => gutterExpanded,
        PersonalLayout.rail => gutterMedium,
        PersonalLayout.bar || PersonalLayout.menu => gutterCompact,
      };

  static bool _cupertino(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// How the personal shell lays its destinations out.
enum PersonalLayout {
  /// Width ≥ [PersonalShellMetrics.sidebarMinWidth]: a 248 dp sidebar.
  sidebar,

  /// Width ≥ [PersonalShellMetrics.railMinWidth]: an 80 dp rail.
  rail,

  /// Compact: a bottom bar with the five destinations.
  bar,

  /// Compact, but the bar has no room (a short window) or the person chose
  /// the menu: a labelled navigation menu holding all five.
  menu,
}

/// The layout of a window [width] × [height] logical pixels (the height as
/// it is with the keyboard CLOSED, so the class does not jump while typing)
/// at [textScalePercent]; [menuPreferred] is the person's explicit menu
/// choice, which the compact class honours. Past the side-navigation text
/// scale a wide window is compact too: the labels no longer fit beside the
/// page.
PersonalLayout personalLayoutOf({
  required double width,
  required double height,
  required double textScalePercent,
  required bool menuPreferred,
}) {
  if (textScalePercent <= kWideNavigationMaxTextScale) {
    if (width >= PersonalShellMetrics.sidebarMinWidth) {
      return PersonalLayout.sidebar;
    }
    if (width >= PersonalShellMetrics.railMinWidth) return PersonalLayout.rail;
  }
  return menuPreferred || height < PersonalShellMetrics.menuMinHeight
      ? PersonalLayout.menu
      : PersonalLayout.bar;
}

/// The personal type scale on the Material roles: size / line / weight.
/// H1 32/40/700 (displaySmall; the compact H1 26/34/700 is headlineSmall),
/// section 20/28/600, card 18/26/600, body 16/24/400, supporting 14/20/400,
/// metadata 13/18/400, action 14/20/600, navigation 15/22 (labelMedium) and
/// compact navigation 12/16 (labelSmall). Heights are line / size, so the
/// reader's text scale grows them together.
TextTheme _personalTextTheme(TextTheme base) {
  TextStyle? role(TextStyle? style, double size, double line, FontWeight weight) =>
      style?.copyWith(fontSize: size, height: line / size, fontWeight: weight);
  return base.copyWith(
    displaySmall: role(base.displaySmall, 32, 40, FontWeight.w700),
    headlineSmall: role(base.headlineSmall, 26, 34, FontWeight.w700),
    titleLarge: role(base.titleLarge, 20, 28, FontWeight.w600),
    titleMedium: role(base.titleMedium, 18, 26, FontWeight.w600),
    bodyLarge: role(base.bodyLarge, 16, 24, FontWeight.w400),
    bodyMedium: role(base.bodyMedium, 14, 20, FontWeight.w400),
    bodySmall: role(base.bodySmall, 13, 18, FontWeight.w400),
    labelLarge: role(base.labelLarge, 14, 20, FontWeight.w600),
    labelMedium: role(base.labelMedium, 15, 22, FontWeight.w500),
    labelSmall: role(base.labelSmall, 12, 16, FontWeight.w500),
  );
}

/// [base] (the product's theme of the same brightness, with its component
/// finish) re-coloured with the personal tokens: the scheme, the surfaces,
/// the header, the cards, the navigation and the type scale. Everything a
/// screen reads through `Theme.of(context)` is the personal layer's; what
/// it reads through [PersonalTheme.of] is the same table.
ThemeData personalThemeFrom(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final t = PersonalTheme.forBrightness(base.brightness);
  final scheme = base.colorScheme.copyWith(
    primary: t.primary,
    onPrimary: t.onPrimary,
    primaryContainer: t.primaryTint,
    onPrimaryContainer: dark ? t.primary : t.text,
    secondaryContainer: t.primaryTint,
    onSecondaryContainer: t.text,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.secondaryText,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.canvas,
    surfaceContainer: t.subtle,
    surfaceContainerHigh: t.subtle,
    surfaceContainerHighest: t.subtle,
    outline: t.interactiveBorder,
    outlineVariant: t.decorativeBorder,
    error: t.danger,
    onError: dark ? t.dangerTint : t.onPrimary,
    errorContainer: t.dangerTint,
    onErrorContainer: t.danger,
  );
  final textTheme = _personalTextTheme(base.textTheme);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: t.canvas,
    canvasColor: t.surface,
    cardColor: t.surface,
    dividerColor: t.decorativeBorder,
    textTheme: textTheme,
    extensions: [...base.extensions.values, t],
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: t.surface,
      foregroundColor: t.text,
      iconTheme: IconThemeData(color: t.secondaryText),
      actionsIconTheme: IconThemeData(color: t.secondaryText),
      shape: Border(bottom: BorderSide(color: t.decorativeBorder)),
      titleTextStyle: textTheme.titleMedium?.copyWith(color: t.text),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: PersonalShellMetrics.cardRadiusAll,
        side: BorderSide(color: t.decorativeBorder),
      ),
    ),
    dividerTheme: DividerThemeData(color: t.decorativeBorder),
    listTileTheme: base.listTileTheme.copyWith(
      iconColor: t.secondaryText,
      selectedTileColor: t.primaryTint,
      selectedColor: t.primary,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: t.surface,
      indicatorColor: t.primaryTint,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: base.drawerTheme.copyWith(backgroundColor: t.surface),
  );
}
