// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: real create fields and actions stay reachable with constrained space.
import 'package:deskilo/features/workspace/presentation/screens/onboarding_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<void> pumpOnboardingLayout(WidgetTester tester, {
  Size size = const Size(360, 740), double scale = 1,
  String locale = 'en', double keyboard = 0,
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
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: const EdgeInsets.only(bottom: 24)),
        child: child!),
      home: const OnboardingScreen(),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale: large text, keyboard, editable draft and Next/Back', (tester) async {
      await pumpOnboardingLayout(tester, scale: 2, locale: locale, keyboard: 260);
      final name = find.byKey(const ValueKey('onboarding-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Independent expected name');
      final next = find.byKey(const ValueKey('wizard-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-currency')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final back = find.byKey(const ValueKey('wizard-back'));
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pump();
      expect(tester.widget<TextFormField>(name).controller!.text,
        'Independent expected name');
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [const Size(740, 320), const Size(1200, 800)]) {
    testWidgets('$size: error, field and primary action can be reached', (tester) async {
      await pumpOnboardingLayout(tester, size: size);
      final next = find.byKey(const ValueKey('wizard-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      final name = find.byKey(const ValueKey('onboarding-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'My space');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-timezone')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
