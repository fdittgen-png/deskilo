// SPDX-License-Identifier: 0BSD
import '../core/ui/system_insets_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/demo/demo_entry.dart';
import '../core/demo/presentation/demo_workspace.dart';
import '../core/locale/locale_controller.dart';
import '../core/motion/motion.dart';
import '../core/presence/presence_providers.dart';
import '../core/theme/theme_controller.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/providers/workspace_providers.dart';
import '../l10n/app_localizations.dart';
import 'boot_splash.dart';
import 'router.dart';
import 'theme.dart';
import 'shell/development_banner.dart';

/// The composition root: the real app, or the demonstration space
/// wrapped around it (#1379).
///
/// The demo is not a different app and has no screens of its own. It is
/// the same [DeskiloApp], built inside a container whose repositories are
/// the fixture's — so the router, the shell and every screen below are
/// the ones a member uses, reading synthetic data.
class DeskiloRoot extends ConsumerWidget {
  const DeskiloRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(demoEntryProvider)
          ? const DemoWorkspace(child: DeskiloApp())
          : const DeskiloApp();
}

/// Composition root of DesKilo.
class DeskiloApp extends ConsumerWidget {
  const DeskiloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Fire-and-forget last-seen heartbeat (#223): runs while signed in
    // and foregrounded, pauses otherwise. Failures only hit the trace.
    ref.watch(presenceBootstrapProvider);
    // Motion pass (#611): the `uiAnimations` flag decides route
    // transitions (baked into the theme) and, via [MotionSettings] in
    // the builder, every in-app animation. Watching the feature set here
    // makes a flag flip rebuild the whole MaterialApp — hot toggle, no
    // restart (the Features screen invalidates the providers).
    final animations = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.uiAnimations);
    // #1289 — the workspace's brand seed, when it chose one and the flag
    // is on; null derives the product's own palette, pixel for pixel.
    final seed = ref.watch(workspaceBrandSeedProvider);
    final brand = seed == null ? null : Color(seed);
    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'DesKilo',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // null keeps the standard system-locale resolution (#147).
      locale: ref.watch(localeControllerProvider).value,
      theme: DeskiloTheme.light(animations: animations, brand: brand),
      darkTheme: DeskiloTheme.dark(animations: animations, brand: brand),
      // null follows the system brightness (#160).
      themeMode:
          ref.watch(themeControllerProvider).value ?? ThemeMode.system,
      // Boot splash (field request): covers every route until the data
      // warm-up finishes — the user never watches the form assemble.
      // MotionSettings sits above the navigator so every screen, sheet
      // and snackbar reads the uiAnimations flag from one place (#611).
      // #917 — the development strip sits ABOVE the navigator, so it
      // shows on every route there is, and above the splash, so it is
      // there from the first frame the workspace is known.
      // #970 — the demo blur sits above everything, banner included.
      builder: (context, child) => MotionSettings(
        animationsEnabled: animations,
        // #1379 — the demonstration bar renders INSIDE the app, where a
        // theme and five languages exist. In live mode there is no
        // DemoEnvironment above it and it returns its child untouched.
        child: DemoControls(
          child: DevelopmentBanner(
            child: BootSplash(child: SystemInsetsGuard(child: child)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
