// SPDX-License-Identifier: 0BSD
//
// Social sign-in + account linking (0051): four browser-OAuth providers
// next to e-mail+password — sign-in buttons on the auth screen, and a
// linked-accounts screen to attach/detach them on an existing account.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/auth/domain/social_provider.dart';
import 'package:deskilo/features/auth/presentation/screens/linked_accounts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../helpers/mock_providers.dart';

void main() {
  Future<FakeAuthRepository> pumpSignedOut(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(auth: auth),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('the auth screen offers all four providers and a tap starts '
      'the OAuth flow', (tester) async {
    final auth = await pumpSignedOut(tester);

    for (final provider in SocialProvider.values) {
      expect(
        find.byKey(ValueKey('auth-social-${provider.name}')),
        findsOneWidget,
        reason: '${provider.name} button missing',
      );
    }

    await tester.tap(find.byKey(const ValueKey('auth-social-google')));
    await tester.pumpAndSettle();
    expect(auth.socialSignIns, [SocialProvider.google]);
  });

  testWidgets('a provider the server has not enabled shows the '
      'unavailable message', (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.socialError = const AuthException('provider is not enabled');

    await tester.tap(find.byKey(const ValueKey('auth-social-facebook')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Facebook'), findsWidgets);
    expect(auth.socialSignIns, isEmpty);
  });

  Future<FakeAuthRepository> pumpLinkedAccounts(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository.signedIn();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(auth: auth),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/linked-accounts');
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('linked accounts: the email identity lists, the four '
      'socials offer Link, linking adds the identity', (tester) async {
    final auth = await pumpLinkedAccounts(tester);

    expect(find.byType(LinkedAccountsScreen), findsOneWidget);
    expect(find.text('email'), findsOneWidget);
    for (final provider in SocialProvider.values) {
      expect(
        find.byKey(ValueKey('link-${provider.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('link-microsoft')));
    await tester.pumpAndSettle();

    expect(auth.socialLinks, [SocialProvider.microsoft]);
    // The reloaded list now shows Microsoft as linked with an Unlink.
    expect(find.byKey(const ValueKey('unlink-azure')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-microsoft')), findsNothing);
  });

  testWidgets('unlink removes the identity; the last one has no unlink '
      'button', (tester) async {
    final auth = await pumpLinkedAccounts(tester);
    auth.identities = [
      (id: 'ident-email', provider: 'email'),
      (id: 'ident-google', provider: 'google'),
    ];
    // Re-open to load the seeded pair.
    await tester.pageBack();
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push('/linked-accounts');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unlink-google')));
    await tester.pumpAndSettle();

    expect(auth.unlinked.single.provider, 'google');
    // Only the email identity remains → no unlink offered on it.
    expect(find.byKey(const ValueKey('unlink-email')), findsNothing);
  });

  testWidgets('settings opens Linked accounts', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-linked-accounts')));
    await tester.pumpAndSettle();

    expect(find.byType(LinkedAccountsScreen), findsOneWidget);
  });
}
