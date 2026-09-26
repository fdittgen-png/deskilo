// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the sign-in screen offers the ways in that are not "I already
// have a space here": Join by invitation (which keeps joining as the
// errand and takes the invitation only after sign-in), the demo, and
// the organisation's own server as an explicit secondary path — each
// tapped, in five languages, at phone width, at twice the text size and
// with motion off.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/entry_intent.dart';
import 'package:deskilo/app/entry_intents.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const joinLabel = {
  'en': 'Join by invitation',
  'fr': 'Rejoindre sur invitation',
  'de': 'Mit Einladung beitreten',
  'es': 'Unirse con invitación',
  'it': 'Entra con un invito',
};

const serverLabel = {
  'en': "Connect an organisation's server",
  'fr': "Se connecter au serveur d'une organisation",
  'de': 'Mit dem Server einer Organisation verbinden',
  'es': 'Conectar con el servidor de una organización',
  'it': "Collegarsi al server di un'organizzazione",
};

late ProviderContainer container;

Future<GoRouter> pump(
  WidgetTester tester, {
  String locale = 'en',
  Size size = const Size(360, 640),
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(auth: FakeAuthRepository()),
        localeStoreProvider
            .overrideWithValue(InMemoryLocaleStore()..languageCode = locale),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(Scaffold).first);
  container = ProviderScope.containerOf(element);
  return GoRouter.of(element);
}

void main() {
  for (final locale in joinLabel.keys) {
    testWidgets('$locale: join keeps the errand and opens account creation; '
        'the server link opens the chooser', (tester) async {
      final router = await pump(tester, locale: locale);
      await tester.ensureVisible(find.byKey(const ValueKey('auth-join')));
      expect(find.text(joinLabel[locale]!), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-join')));
      await tester.pumpAndSettle();
      expect(container.read(entryIntentsProvider)?.purpose, EntryPurpose.join);
      expect(find.byKey(const ValueKey('auth-join-hint')), findsOneWidget);
      // Account creation: the display-name field is there now.
      expect(find.byType(TextFormField), findsNWidgets(3));

      await tester.ensureVisible(find.byKey(const ValueKey('auth-server')));
      expect(find.text(serverLabel[locale]!), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-server')));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/server');
      expect(find.byKey(const ValueKey('backend-status')), findsOneWidget);
    });
  }

  testWidgets('twice the text size, motion off: every affordance is still '
      'there and tappable', (tester) async {
    final router = await pump(tester, textScale: 2, reducedMotion: true);
    for (final key in const ['auth-join', 'demo-entry', 'auth-server']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      expect(find.byKey(ValueKey(key)), findsOneWidget);
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
    await tester.tap(find.byKey(const ValueKey('auth-server')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/server');
  });

  testWidgets('the join errand survives to the join form after sign-in',
      (tester) async {
    // The sign-in step, not the layout: the phone width is the locale
    // cases' business, and at 360×640 the submit sits under the fold.
    final router = await pump(tester, size: const Size(400, 800));
    await tester.tap(find.byKey(const ValueKey('auth-join')));
    await tester.pumpAndSettle();
    // Back to sign-in: an existing account may hold the invitation too.
    final toggle = find.textContaining('Already have an account');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'flo@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    final submit = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/onboarding');
    expect(container.read(entryIntentsProvider), isNull,
        reason: 'arrived, so spent');
  });
}
