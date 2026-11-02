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
import 'package:deskilo/core/app_info.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
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
  double keyboardInset = 0,
  String? appVersion,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(auth: FakeAuthRepository()),
        if (appVersion != null) appVersionProvider.overrideWith((ref) async => appVersion),
        localeStoreProvider
            .overrideWithValue(InMemoryLocaleStore()..languageCode = locale),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
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
    testWidgets('$locale: build footer is localized and at the bottom', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, locale: locale, size: const Size(400, 1200), appVersion: '1.2.3+42');
      final footer = find.byKey(const ValueKey('auth-build-version'));
      expect(footer, findsOneWidget);
      final label = switch (locale) {
        'it' => 'Versione 1.2.3+42',
        'es' => 'Versión 1.2.3+42',
        _ => 'Version 1.2.3+42',
      };
      expect(find.descendant(of: footer, matching: find.text(label)), findsOneWidget);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(tester.getBottomLeft(footer).dy, closeTo(1176, 1));
      semantics.dispose();
    });
  }

  testWidgets('unavailable metadata does not invent a build', (tester) async {
    await pump(tester, appVersion: '');
    expect(find.byKey(const ValueKey('auth-build-version')), findsNothing);
    expect(find.byKey(const ValueKey('demo-entry')), findsOneWidget);
  });

  testWidgets('small keyboard viewport keeps version and Demo reachable', (tester) async {
    await pump(tester, keyboardInset: 260,
        textScale: 2, reducedMotion: true, appVersion: '1.2.3');
    final footer = find.byKey(const ValueKey('auth-build-version'));
    await tester.ensureVisible(footer);
    expect(tester.getBottomLeft(footer).dy, lessThanOrEqualTo(380));
    expect(find.descendant(of: footer, matching: find.text('Version 1.2.3')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('demo-entry')));
    expect(find.byKey(const ValueKey('demo-entry')).hitTestable(), findsOneWidget);
  });

  testWidgets('build footer keeps the actual Demo entry reachable', (tester) async {
    await pump(tester, size: const Size(400, 900), appVersion: '1.2.3+42');
    expect(find.byKey(const ValueKey('auth-build-version')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('demo-entry')));
    await tester.tap(find.byKey(const ValueKey('demo-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    expect(container.read(demoEntryProvider), isFalse);
    await tester.tap(find.byKey(const Key('demo-entry-start')));
    // The state changes on consent; one frame observes it without waiting on
    // unrelated animations in the Demo shell.
    await tester.pump();
    expect(container.read(demoEntryProvider), isTrue);
  });

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

  // #2400 — the welcome page's "Try the demo" lands on /auth?demo=1.
  testWidgets('a demo link opens the explanation, which still asks first',
      (tester) async {
    final router = await pump(tester);
    expect(find.byKey(const Key('demo-entry-start')), findsNothing,
        reason: 'the plain sign-in screen offers, it does not open');
    router.go('/auth?demo=1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-entry-start')), findsOneWidget);
    expect(container.read(demoEntryProvider), isFalse,
        reason: 'reading the explanation is not consenting to it');
  });

  testWidgets('the join errand survives to the join form after sign-in',
      (tester) async {
    // The sign-in step, not the layout: the phone width is the locale
    // cases' business, and at 360×640 the submit sits under the fold.
    // #2459: 900 high — the form gained the welcome link's row.
    final router = await pump(tester, size: const Size(400, 900));
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
    expect(router.state.uri.toString(), '/onboarding?join=1');
    // #1652 — the invitation errand arrives on Join, not on Create.
    expect(find.byKey(const ValueKey('invitation-input')), findsOneWidget);
    expect(container.read(entryIntentsProvider), isNull,
        reason: 'arrived, so spent');
  });
}
