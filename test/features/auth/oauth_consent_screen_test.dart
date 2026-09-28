// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648: the real route dispatches protected identity consent without a
// workspace/MCP grant; taps approve/deny once, auto-returns once, and a late
// response after leaving the screen cannot launch a credential-bearing URL.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/oauth_consent_repository.dart';
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/features/auth/domain/oauth_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _id = 'abcdefghijklmnopqrstuvwxyzABCDEF';
final _context = OAuthConsentContext(
  purpose: OAuthConsentPurpose.identityFederation,
  clientId: 'identity-client',
  localUserId: 'user-1',
  targetAuthUrl: Uri.parse('https://organization.example/auth/v1'),
  targetInstallationId: 'organization',
);
final _return = Uri.parse('https://organization.example/auth/v1/callback?code=one-use');
final _denied = Uri.parse('https://organization.example/auth/v1/callback?error=access_denied');

FakeOAuthConsentRepository _repo({bool alreadyApproved = false}) =>
    FakeOAuthConsentRepository(
      request: OAuthConsentRequest(context: _context,
          returnUri: alreadyApproved ? _return : null),
      approved: _return,
      denied: _denied,
    );

Future<GoRouter> _pump(WidgetTester tester, OAuthConsentRepository repository,
    List<Uri> launched, {bool launchSucceeds = true}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...standardTestOverrides(oauthConsent: repository,
          workspace: FakeWorkspaceRepository()),
      linkLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return launchSucceeds;
      }),
    ],
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  unawaited(router.push('/oauth/consent?authorization_id=$_id'));
  await tester.pumpAndSettle();
  return router;
}

class _Delayed extends FakeOAuthConsentRepository {
  _Delayed() : super(request: OAuthConsentRequest(context: _context));
  final answer = Completer<Uri>();
  @override
  Future<Uri> approve(String id, OAuthConsentContext context) => answer.future;
}

void main() {
  for (final language in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('identity consent: $language at narrow width and large text', (tester) async {
      tester.platformDispatcher.localesTestValue = [Locale(language)];
      tester.platformDispatcher.localeTestValue = Locale(language);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
      final launched = <Uri>[];
      await _pump(tester, _repo(), launched);
      final button = find.byKey(const ValueKey('identity-consent-approve'));
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(launched, [_return]);
      expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
  testWidgets('no workspace: names destination and approves once without MCP',
      (tester) async {
    final repo = _repo();
    final launched = <Uri>[];
    await _pump(tester, repo, launched);
    expect(find.byKey(const ValueKey('identity-consent-destination')), findsOneWidget);
    expect(find.textContaining('organization.example'), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-consent-request-eligibility')), findsNothing);
    final button = find.byKey(const ValueKey('identity-consent-approve'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.calls.where((call) => call == 'approve'), hasLength(1));
    expect(launched, [_return]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel denies Auth and returns only the refusal', (tester) async {
    final repo = _repo();
    final launched = <Uri>[];
    await _pump(tester, repo, launched);
    await tester.tap(find.byKey(const ValueKey('identity-consent-deny')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((call) => call == 'deny'), hasLength(1));
    expect(repo.calls, isNot(contains('approve')));
    expect(launched, [_denied]);
  });

  testWidgets('prior consent returns once; failed launch retries only on tap',
      (tester) async {
    final repo = _repo(alreadyApproved: true);
    final launched = <Uri>[];
    await _pump(tester, repo, launched, launchSucceeds: false);
    await tester.pumpAndSettle();
    expect(launched, [_return]);
    expect(repo.calls, isNot(contains('approve')));
    await tester.tap(find.byKey(const ValueKey('identity-consent-retry-return')));
    await tester.pumpAndSettle();
    expect(launched, [_return, _return]);
  });

  testWidgets('unavailable request exposes a remedy without any consent action',
      (tester) async {
    final launched = <Uri>[];
    await _pump(tester, FakeOAuthConsentRepository(), launched);
    expect(find.byKey(const ValueKey('identity-consent-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('identity-consent-approve')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('leaving while Auth answers suppresses the late return', (tester) async {
    final repo = _Delayed();
    final launched = <Uri>[];
    final router = await _pump(tester, repo, launched);
    await tester.tap(find.byKey(const ValueKey('identity-consent-approve')));
    router.pop();
    await tester.pumpAndSettle();
    repo.answer.complete(_return);
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
