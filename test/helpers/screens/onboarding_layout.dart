// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the onboarding screen pump, moved out of `test/features/workspace/onboarding_layout_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/core/motion/motion.dart';
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../mock_providers.dart';

Future<void> pumpOnboardingLayout(WidgetTester tester, {
  Size size = const Size(360, 740), double? scale,
  String locale = 'en', double keyboard = 0, bool animations = true, bool? reducedMotion,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: FakeWorkspaceRepository()),
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion ?? MediaQuery.disableAnimationsOf(context),
          textScaler: scale == null ? MediaQuery.textScalerOf(context)
              : TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: const EdgeInsets.only(bottom: 24)),
        child: child!),
      home: MotionSettings(animationsEnabled: animations,
        child: const OnboardingScreen()),
    ),
  ));
  await tester.pump();
}
