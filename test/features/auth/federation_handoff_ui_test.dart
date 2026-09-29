// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648 — the handoff as a member meets it: the real app and router, the
// real repository, callback guard, dispatcher and isolated SDK exchange;
// only the system browser and the target's HTTP answers are faked.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/entry_intents.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/features/auth/application/federation_handoff_controller.dart';
import 'package:deskilo/features/auth/domain/federation_port.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/federation_fixture.dart';
import '../../helpers/mock_providers.dart';

late ProviderContainer container;

Future<(GoRouter, FederationTarget)> pump(
  WidgetTester tester, {
  String locale = 'en',
  Size size = const Size(420, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Built and disposed on real time: every SDK client owns a JSON isolate,
  // which fake time can neither start nor stop.
  final target = (await tester.runAsync(
    () async => FederationTarget('https://target.example'),
  ))!;
  addTearDown(() => tester.runAsync(target.dispose));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(auth: target.repository),
        localeStoreProvider.overrideWithValue(
          InMemoryLocaleStore()..languageCode = locale,
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(Scaffold).first);
  container = ProviderScope.containerOf(element);
  return (GoRouter.of(element), target);
}

final continueButton = find.byKey(const ValueKey('auth-social-deskilo'));

/// The isolated SDK client starts and stops a real JSON isolate, which
/// fake time can neither run nor finish: alternate one real event-loop turn
/// with a frame of fake time until [done] holds, never a guessed delay.
Future<void> settle(
  WidgetTester tester,
  bool Function() done, {
  required String what,
}) async {
  final watch = Stopwatch()..start();
  while (!done()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('$what did not finish within 20 s of real time');
    }
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(const Duration(milliseconds: 5));
  }
}

FederationHandoffState handoff() =>
    container.read(federationHandoffControllerProvider);

/// Until the browser was handed the flow (or refused to start).
Future<void> opened(WidgetTester tester) => settle(
  tester,
  () => handoff().stage != FederationStage.opening,
  what: 'opening the browser',
);

Future<void> tapContinue(WidgetTester tester) async {
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pump();
  await opened(tester);
}

/// The OS hands the app its return, through the one dispatcher; the
/// exchange then runs until it has answered.
Future<bool> deliver(
  WidgetTester tester,
  FederationTarget target,
  Uri uri,
) async {
  final before = target.completions.length;
  target.dispatch(uri);
  final owned = target.completions.length > before;
  var done = false;
  unawaited(Future.wait(target.completions).whenComplete(() => done = true));
  await settle(tester, () => done, what: 'the returned sign-in');
  await tester.pump();
  return owned;
}

void main() {
  testWidgets('one explicit Continue with Deskilo: one browser, the true '
      'stage, and the saved errand resumes after the verified return', (
    tester,
  ) async {
    final (router, target) = await pump(tester);
    // The errand chosen before signing in (#1650).
    await tester.ensureVisible(find.byKey(const ValueKey('auth-join')));
    await tester.tap(find.byKey(const ValueKey('auth-join')));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Deskilo'), findsOneWidget);
    expect(find.byKey(const ValueKey('federation-purpose')), findsOneWidget);
    expect(find.textContaining('target.example'), findsWidgets);
    // Safe technical details on demand: host names, nothing else.
    await tester.ensureVisible(
      find.byKey(const ValueKey('federation-details')),
    );
    await tester.tap(find.byKey(const ValueKey('federation-details')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Identity authority: identity.example'),
      findsOneWidget,
    );
    expect(find.textContaining(fixtureInstallation), findsNothing);

    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pump();
    await opened(tester);
    expect(target.launches, hasLength(1), reason: 'a double tap, one browser');
    expect(find.text('Waiting for sign-in in your browser…'), findsOneWidget);

    // Background and back, with no return yet: still waiting, once.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.text('Waiting for sign-in in your browser…'), findsOneWidget);
    expect(target.launches, hasLength(1));

    // The delayed return.
    expect(
      await deliver(tester, target, target.returnFor({'code': 'target-code'})),
      true,
    );
    await tester.pumpAndSettle();
    expect(target.active.auth.currentUser?.id, 'target-person');
    expect(
      router.state.uri.toString(),
      '/onboarding',
      reason: 'the saved errand, with no extra Connected→Continue step',
    );
    expect(
      container.read(entryIntentsProvider),
      isNull,
      reason: 'arrived, so spent',
    );
    expect(target.calls, isNot(contains('/auth/v1/signup')));
  });

  testWidgets('cancel returns keyboard focus to the action and keeps the '
      'form; the late return is refused', (tester) async {
    final (router, target) = await pump(tester);
    await tapContinue(tester);
    final late = target.returnFor({'code': 'target-code'});
    await tester.tap(find.byKey(const ValueKey('federation-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('federation-stage')), findsNothing);
    final button = tester.widget<OutlinedButton>(continueButton);
    expect(button.focusNode!.hasFocus, true);
    expect(await deliver(tester, target, late), false);
    await tester.pumpAndSettle();
    expect(
      router.state.uri.toString(),
      '/auth',
      reason: 'no surprise navigation',
    );
    expect(target.active.auth.currentUser, isNull);
  });

  for (final locale in const ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale: the stage and the refusal are worded, and nothing '
        'suggests creating a local account', (tester) async {
      final l10n = lookupAppLocalizations(Locale(locale));
      final (_, target) = await pump(tester, locale: locale);
      expect(find.text(l10n.authToggleToSignUp), findsNothing);
      await tapContinue(tester);
      expect(find.text(l10n.federationStageWaiting), findsOneWidget);
      await deliver(
        tester,
        target,
        target.returnFor({'error': 'access_denied'}),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.federationFailureRefused), findsOneWidget);
      expect(find.text(l10n.federationRetry), findsOneWidget);
      expect(find.text(l10n.authToggleToSignUp), findsNothing);
      expect(find.text(l10n.authSignUpButton), findsNothing);
      await tester.tap(find.text(l10n.federationRetry));
      await tester.pump();
      await opened(tester);
      expect(
        target.launches,
        hasLength(2),
        reason: 'retry is the second explicit attempt',
      );
    });
  }

  testWidgets('an unlinked existing account leads to signing in to it — '
      'the sign-in form, focused, never account creation', (tester) async {
    final (_, target) = await pump(tester);
    target.binding = {
      'status': 'conflict',
      'reason': 'subject_bound_to_another_user',
    };
    await tapContinue(tester);
    await deliver(tester, target, target.returnFor({'code': 'target-code'}));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('federation-failure-unlinkedAccount')),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing is merged'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('federation-existing-account')));
    await tester.pumpAndSettle();
    expect(target.active.auth.currentUser, isNull);
    expect(find.text('Display name'), findsNothing, reason: 'sign-in form');
    final email = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(email.focusNode.hasFocus, true);
  });

  testWidgets('an incompatible server offers its review; a missing '
      'provider offers no retry', (tester) async {
    final (router, target) = await pump(tester);
    target.advertisedIssuer = 'https://other.example';
    await tapContinue(tester);
    await deliver(tester, target, target.returnFor({'code': 'target-code'}));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('federation-failure-incompatibleServer')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('federation-retry')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('federation-review-server')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/server');

    router.pop();
    await tester.pumpAndSettle();
    target.authority = null;
    await tapContinue(tester);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('federation-failure-providerMissing')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('federation-retry')), findsNothing);
    expect(target.launches, hasLength(1));
  });

  testWidgets('at phone width and twice the text size the handoff wraps, '
      'with no overflow', (tester) async {
    final (_, target) = await pump(
      tester,
      size: const Size(320, 2400),
      textScale: 2,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('federation-details')),
    );
    await tester.tap(find.byKey(const ValueKey('federation-details')));
    await tester.pumpAndSettle();
    await tapContinue(tester);
    expect(find.byKey(const ValueKey('federation-stage')), findsOneWidget);
    await deliver(tester, target, target.returnFor({'error': 'access_denied'}));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('federation-retry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
