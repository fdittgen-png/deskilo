// SPDX-License-Identifier: 0BSD
import 'package:flex_color_scheme/flex_color_scheme.dart';
// #667 — CupertinoPageTransitionsBuilder is no longer re-exported by
// material.dart as of Flutter 3.44; it lives in the cupertino library.
import 'package:flutter/cupertino.dart';
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
  final scheme = base.colorScheme;
  return base.copyWith(
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
      centerTitle: false,
      titleSpacing: 20,
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
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
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

/// The three DesKilo themes: [light], [dark], and the signature
/// orange-forward [warm] (the analog of Sparkilo's eco theme).
/// [animations] carries the `uiAnimations` feature (#611) into the
/// route-transition theme; everything else is identical either way.
abstract final class DeskiloTheme {
  static ThemeData light({bool animations = true}) {
    return _finish(
      FlexThemeData.light(
        colors: _burntOrange,
        blendLevel: 8,
        subThemesData: _subThemes,
        useMaterial3: true,
      ),
      animations: animations,
    );
  }

  static ThemeData dark({bool animations = true}) {
    return _finish(
      FlexThemeData.dark(
        colors: _burntOrange.toDark(28),
        blendLevel: 22,
        subThemesData: _subThemes,
        useMaterial3: true,
      ),
      animations: animations,
    );
  }

  static ThemeData warm({bool animations = true}) {
    return _finish(
      FlexThemeData.light(
        colors: _burntOrange,
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
