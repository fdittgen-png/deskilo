// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the real router with the real screens: what the person asked
// for before sign-in is where they land after it — through
// verification and consent — instead of the Reserve hub; the draft
// survives a restart, dies with sign-out, is refused for another
// account, and a late answer for one continuation never spends another.
// The Demo keeps its own copy and consumes nothing of the live one.

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/entry_intent.dart';
import 'package:deskilo/app/entry_intents.dart';
import 'package:deskilo/core/storage/entry_intent_store.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fake_profile_repository.dart';
import '../helpers/mock_providers.dart';

late ProviderContainer container;

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  required InMemoryEntryIntentStore store,
  FakeProfileRepository? profile,
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // A ProviderScope, not an uncontrolled one: the scope disposes its
  // container when the tree goes, before flutter_test checks for timers;
  // a container disposed in a tearDown leaves the presence heartbeat's
  // timer pending at that check.
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        auth: auth,
        profile: profile,
        workspace: workspace,
        entryIntent: store,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final element = tester.element(find.byType(Scaffold).first);
  container = ProviderScope.containerOf(element);
  return GoRouter.of(element);
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'flo@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

String location(GoRouter router) => router.state.uri.toString();

void main() {
  testWidgets('a deep link before sign-in is where sign-in lands, not the '
      'hub — and the draft is written once and spent once', (tester) async {
    final store = InMemoryEntryIntentStore();
    final router = await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      store: store,
    );
    router.go('/help?topic=Privacy');
    await tester.pumpAndSettle();
    // A public route: nothing to come back to, nothing written.
    expect(location(router), '/help?topic=Privacy');
    expect(store.writes, 0);

    router.go('/money');
    await tester.pumpAndSettle();
    expect(location(router), '/auth');
    expect(store.writes, 1);
    expect(store.value, contains('"target":"/money"'));

    await signIn(tester);
    expect(location(router), '/money');
    expect(container.read(entryIntentsProvider), isNull);
    expect(store.value, isNull);
  });

  testWidgets('verification, then consent, then the exact target',
      (tester) async {
    final store = InMemoryEntryIntentStore();
    final auth = FakeAuthRepository()
      ..signInResult = const AuthResult.verificationRequired();
    final profile = FakeProfileRepository(
      profiles: [const Profile(id: 'user-1', displayName: 'Flo')],
      accepted: false,
    );
    final router =
        await pumpApp(tester, auth: auth, store: store, profile: profile);
    router.go('/linked-accounts');
    await tester.pumpAndSettle();
    expect(location(router), '/auth');

    await signIn(tester);
    // The e-mail went out; the intent waits with the person.
    expect(find.byKey(const ValueKey('auth-pending')), findsOneWidget);
    expect(container.read(entryIntentsProvider)?.destination,
        '/linked-accounts');

    // The link in the e-mail confirms the address: a session appears.
    auth.signInAs('user-1');
    await tester.pumpAndSettle();
    expect(location(router), '/consent');
    await tester.tap(find.byKey(const ValueKey('consent-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('consent-accept')));
    await tester.pumpAndSettle();
    expect(location(router), '/linked-accounts');
    expect(container.read(entryIntentsProvider), isNull);
  });

  testWidgets('a restart resumes the draft; an expired one is dropped',
      (tester) async {
    final live = EntryIntentDraft(
      intent: const EntryIntent.openValidated('d1', '/privacy'),
      installation: kDefaultInstallation,
      userId: null,
      expiresAt: kTestNow.add(const Duration(hours: 1)),
    ).encode();
    final router = await pumpApp(
      tester,
      auth: FakeAuthRepository(),
      store: InMemoryEntryIntentStore(live),
    );
    await signIn(tester);
    expect(location(router), '/privacy');
  });

  for (final (why, draft) in [
    (
      'expired',
      EntryIntentDraft(
        intent: const EntryIntent.openValidated('x', '/privacy'),
        installation: kDefaultInstallation,
        userId: null,
        expiresAt: kTestNow.subtract(const Duration(minutes: 1)),
      )
    ),
    (
      'from another installation',
      EntryIntentDraft(
        intent: const EntryIntent.openValidated('y', '/privacy'),
        installation: 'https://other.example',
        userId: null,
        expiresAt: kTestNow.add(const Duration(hours: 1)),
      )
    ),
    (
      'for another account',
      EntryIntentDraft(
        intent: const EntryIntent.openValidated('z', '/privacy'),
        installation: kDefaultInstallation,
        userId: 'somebody-else',
        expiresAt: kTestNow.add(const Duration(hours: 1)),
      )
    ),
  ]) {
    testWidgets('a draft $why is dropped unread', (tester) async {
      final store = InMemoryEntryIntentStore(draft.encode());
      final router = await pumpApp(
        tester,
        auth: FakeAuthRepository.signedIn(),
        store: store,
      );
      expect(location(router), '/reserve');
      expect(store.value, isNull, reason: 'the draft is cleared, not kept');
      expect(container.read(entryIntentsProvider), isNull);
    });
  }

  testWidgets('sign-out forgets the continuation', (tester) async {
    final store = InMemoryEntryIntentStore();
    final auth = FakeAuthRepository.signedIn();
    await pumpApp(tester, auth: auth, store: store);
    await container
        .read(entryIntentsProvider.notifier)
        .capture(const EntryIntent.join('j', workspaceHint: 'Space'));
    expect(store.value, isNotNull);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(container.read(entryIntentsProvider), isNull);
    expect(store.value, isNull);
  });

  testWidgets('a late answer for A never spends B', (tester) async {
    final store = InMemoryEntryIntentStore();
    await pumpApp(tester, auth: FakeAuthRepository.signedIn(), store: store);
    final intents = container.read(entryIntentsProvider.notifier);
    await intents.capture(const EntryIntent.openValidated('A', '/money'));
    await intents.capture(const EntryIntent.openValidated('B', '/privacy'));
    await intents.consume('A');
    expect(container.read(entryIntentsProvider)?.id, 'B');
    await intents.consume('B');
    expect(container.read(entryIntentsProvider), isNull);
  });

  testWidgets('the demonstration keeps its own copy: entering it neither '
      'reads nor spends the live draft', (tester) async {
    final store = InMemoryEntryIntentStore(EntryIntentDraft(
      intent: const EntryIntent.openValidated('live', '/privacy'),
      installation: kDefaultInstallation,
      userId: null,
      expiresAt: kTestNow.add(const Duration(hours: 1)),
    ).encode());
    await pumpApp(tester, auth: FakeAuthRepository(), store: store);
    final before = store.writes;
    await tester.tap(find.byKey(const ValueKey('demo-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-entry-start')));
    await tester.pumpAndSettle();
    expect(store.writes, before);
    expect(store.value, contains('"target":"/privacy"'));
  });
}
