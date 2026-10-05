// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flex_color_scheme/flex_color_scheme.dart';
// #667 — CupertinoPageTransitionsBuilder is no longer re-exported by
// material.dart as of Flutter 3.44; it lives in the cupertino library.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/contrast.dart';
import '../core/theme/contrast_audit.dart';

import '../core/theme/app_radius.dart';
import '../core/theme/shell_metrics.dart';

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
  // Dense, tighter form fields app-wide: every TextField / dropdown reads
  // more professional and takes less vertical space, so long forms
  // (settings, booking, editors) fit more on screen without scrolling.
  inputDecoratorIsDense: true,
  inputDecoratorContentPadding:
      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  snackBarRadius: AppRadius.lg,
);

/// The shared type-and-surface finish (design pass, needs analysis):
/// screen titles get real presence (w700, tight tracking) instead of the
/// system default; chips read as one calm family with a hairline border;
/// cards sit flat on tonal surfaces (depth comes from [AppElevation]
/// where it means something, not from Material's default drop shadow).
ThemeData _finish(ThemeData base, {required bool animations}) {
  final raw = base.colorScheme;
  // #721 — the pairs the app reads most, guaranteed rather than hoped:
  // the audit test (test/lint/contrast_test.dart) measures exactly these
  // and found the dark primary's label at 3.2:1, the light outline at
  // 2.9:1, dark error text at 4.2:1. Each is nudged in lightness only.
  // #1289 — the fills first, then their labels against the FINAL fill:
  // a seed that has to be darkened to read as text on a surface (yellow,
  // sky) or lightened in the dark scheme (navy) would otherwise keep a
  // label that was checked against the colour it no longer is.
  final primary = Contrast.ensure(raw.primary, raw.surfaceContainerHighest);
  final error = Contrast.ensure(raw.error, raw.surfaceContainerHighest);
  final scheme = raw.copyWith(
    onPrimary: Contrast.ensure(raw.onPrimary, primary),
    onSecondaryContainer:
        Contrast.ensure(raw.onSecondaryContainer, raw.secondaryContainer),
    onPrimaryContainer:
        Contrast.ensure(raw.onPrimaryContainer, raw.primaryContainer),
    onError: Contrast.ensure(raw.onError, error),
    onErrorContainer: Contrast.ensure(raw.onErrorContainer, raw.errorContainer),
    onSecondary: Contrast.ensure(raw.onSecondary, raw.secondary),
    onTertiary: Contrast.ensure(raw.onTertiary, raw.tertiary),
    error: error,
    primary: primary,
    onSurfaceVariant:
        Contrast.ensure(raw.onSurfaceVariant, raw.surfaceContainerHighest),
    // Against the container the outline sits on most and contrasts with
    // least — the highest tint — so every lighter surface passes too.
    outline: Contrast.ensure(raw.outline, raw.surfaceContainerHighest, floor: 3.0),
  );
  final dark = scheme.brightness == Brightness.dark;
  // The GitHub-style chrome (design request 2026-10-05): a flat bar of the
  // page's own colour closed by a hairline, rounded-square outlined icon
  // buttons, a blue notification mark, calm Primer-like grey ink.
  final page = dark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);
  final bar = dark ? const Color(0xFF010409) : const Color(0xFFF6F8FA);
  final line = dark ? const Color(0xFF3D444D) : const Color(0xFFD1D9E0);
  final ink = dark ? const Color(0xFF9198A1) : const Color(0xFF59636E);
  final blue = dark ? const Color(0xFF4493F8) : const Color(0xFF0969DA);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: page,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: line),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: ink),
    badgeTheme: BadgeThemeData(
      backgroundColor: blue,
      textColor: Colors.white,
    ),
    pageTransitionsTheme: _pageTransitions(animations: animations),
    textTheme: base.textTheme.copyWith(
      // The app-bar title: confident, a touch tighter — personality
      // without a custom font dependency.
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bar,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      iconTheme: IconThemeData(color: ink),
      actionsIconTheme: IconThemeData(color: ink),
      shape: Border(bottom: BorderSide(color: line)),
      centerTitle: false,
      titleSpacing: 20,
      // One toolbar height for the whole app (shell_metrics.dart).
      toolbarHeight: kAppToolbarHeight,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      labelStyle: base.textTheme.labelLarge,
      // Denser chips app-wide (screenshot feedback 2026-07-20: the header
      // chip rows ate too much space). Tighter label + shell padding
      // narrows every chip — date pills, window/level chips, billing
      // filter chips, member status chips — while the ambient padded tap
      // target keeps them above the 44dp floor the touch-target guard
      // enforces. (ChipThemeData has no visualDensity; a global one would
      // shrink IconButtons below the 48dp guard, so we tighten padding.)
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    // One card everywhere: a flat surface, a hairline, one radius — never
    // a beige slab. Lists, hints, forms and summaries all read as the same
    // object.
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: line),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      dividerColor: line,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 0.8,
    ),
  );
}

/// Route transitions of the motion pass (#611): fade-forwards (the M3
/// fade-through successor of the zoom default) on Android and every
/// desktop/web platform, Cupertino on iOS so the native back-swipe
/// stays. Each builder is wrapped reduced-motion-aware: when the
/// platform asks for no animations the pushed page just appears.
///
/// `animations: false` (the `uiAnimations` feature off) swaps in the
/// instant builder for every platform. The bool is baked into the
/// ThemeData on purpose — the app root watches the feature set, so a
/// flag flip rebuilds MaterialApp with the other theme immediately (the
/// Features screen invalidates the providers on toggle).
PageTransitionsTheme _pageTransitions({required bool animations}) {
  if (!animations) {
    return PageTransitionsTheme(builders: {
      for (final platform in TargetPlatform.values)
        platform: const _InstantPageTransitionsBuilder(),
    });
  }
  const fade =
      _ReducedMotionAware(FadeForwardsPageTransitionsBuilder());
  const cupertino = _ReducedMotionAware(CupertinoPageTransitionsBuilder());
  return const PageTransitionsTheme(builders: {
    TargetPlatform.android: fade,
    TargetPlatform.fuchsia: fade,
    TargetPlatform.linux: fade,
    TargetPlatform.windows: fade,
    TargetPlatform.macOS: fade,
    TargetPlatform.iOS: cupertino,
  });
}

/// No transition at all: the new route is simply there.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

/// Delegates to [_delegate] unless the platform requests reduced motion
/// — then the route content renders static (no fade, no slide).
class _ReducedMotionAware extends PageTransitionsBuilder {
  const _ReducedMotionAware(this._delegate);

  final PageTransitionsBuilder _delegate;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _delegate.buildTransitions(
        route, context, animation, secondaryAnimation, child);
  }
}

/// #1289 — a workspace's brand seed, derived into a whole scheme the way
/// the product's own is: one colour in, secondary and tertiary derived,
/// containers derived, then the same `_finish` nudges. Null is the
/// product palette, pixel-identical to before the seed existed.
FlexSchemeColor _colorsFor(Color? brand) => brand == null
    ? _burntOrange
    : FlexSchemeColor.from(primary: brand, brightness: Brightness.light);

/// The three DesKilo themes: [light], [dark], and the signature
/// orange-forward [warm] (the analog of Sparkilo's eco theme).
/// [animations] carries the `uiAnimations` feature (#611) into the
/// route-transition theme; everything else is identical either way.
/// [brand] is a workspace's seed colour (#1289), null for the product's.
abstract final class DeskiloTheme {
  /// #1823 — DesKilo's own ink-blue, the seed of the Me layer. Never a
  /// workspace's: the person's layer wears the product's identity.
  static const Color meLayerSeed = Color(0xFF2F3D5C);

  static ThemeData light({bool animations = true, Color? brand}) {
    return _finish(
      FlexThemeData.light(
        colors: _colorsFor(brand),
        blendLevel: 8,
        subThemesData: _subThemes,
        useMaterial3: true,
      ),
      animations: animations,
    );
  }

  static ThemeData dark({bool animations = true, Color? brand}) {
    return _finish(
      FlexThemeData.dark(
        colors: _colorsFor(brand).toDark(28),
        blendLevel: 22,
        subThemesData: _subThemes,
        useMaterial3: true,
      ),
      animations: animations,
    );
  }

  /// #1289 — why a brand seed cannot be used: every pair that would read
  /// below its floor, in the three schemes it derives, through the one
  /// checker the accessibility lint runs. Empty means it may be used.
  ///
  /// This is the refusal itself: a colour is measured at the moment it is
  /// chosen (a questionnaire's document, an import, a template, later a
  /// picker) rather than stored and discovered by a member who cannot
  /// read the screen.
  static List<ContrastFailure> refusals(Color brand) => [
        for (final scheme in [
          light(brand: brand),
          dark(brand: brand),
          warm(brand: brand),
        ])
          ...auditThemeContrast(scheme),
      ];

  static ThemeData warm({bool animations = true, Color? brand}) {
    return _finish(
      FlexThemeData.light(
        colors: _colorsFor(brand),
        blendLevel: 20,
        // custom pulls the scheme's appBarColor (the warm container tint).
        appBarStyle: FlexAppBarStyle.custom,
        subThemesData: _subThemes,
        useMaterial3: true,
      ),
      animations: animations,
    );
  }
}
