// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — a creation is an intent frozen when it is sent. One test
// workspace is the default and the confirm step says how many workspaces,
// on which server and whether any bills for real. A country change keeps
// the owner's own currency and zone, and only the catalogue's codes pass.
// After a response that never came, the payload may not change until a
// retry of the SAME request has found out what happened, and a restart
// resumes that request for the account that sent it, and no other.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/application/creation_intent.dart';
import 'package:deskilo/features/workspace/application/start_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pump(
  WidgetTester tester, {
  InMemoryCreationDraftStore? drafts,
}) async {
  final repo = FakeWorkspaceRepository();
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(workspace: repo, creationDraft: drafts),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> goTo(WidgetTester tester, String label) async {
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> pressCreate(WidgetTester tester) async {
  await tapKey(tester, 'onboarding-create');
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
      .hideCurrentSnackBar();
  await tester.pumpAndSettle();
}

const intent = CreationIntent(
  requestId: '6b1d3f0e-0000-4000-8000-000000000001',
  name: 'Kraftwerk',
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  shape: CreationShape.test,
  templateId: null,
);

void main() {
  group('the pure contract', () {
    test('each shape says how many it makes and whether one bills', () {
      expect(CreationShape.test.workspaceCount, 1);
      expect(CreationShape.test.realBilling, isFalse);
      expect(CreationShape.test.withTwin, isFalse);
      expect(CreationShape.real.workspaceCount, 1);
      expect(CreationShape.real.realBilling, isTrue);
      expect(CreationShape.pair.workspaceCount, 2);
      expect(CreationShape.pair.withTwin, isTrue);
    });

    test('only catalogue currencies and installable zones are placeable', () {
      expect(isPlaceable(currencyCode: 'eur', timezone: 'Europe/Paris'), isTrue);
      expect(isPlaceable(currencyCode: 'EURO', timezone: 'Europe/Paris'), isFalse);
      expect(isPlaceable(currencyCode: 'XYZ', timezone: 'Europe/Paris'), isFalse);
      expect(isPlaceable(currencyCode: 'EUR', timezone: 'Europe/Pairs'), isFalse);
    });

    test('only the server refusing the template is a template refusal', () {
      expect(isTemplateRefusal(Exception('not supported: no forms')), isTrue);
      expect(isTemplateRefusal(Exception('unknown template')), isTrue);
      expect(isTemplateRefusal(Exception('SocketException: reset')), isFalse);
      expect(isTemplateRefusal(StateError('the response was lost')), isFalse);
    });

    test('a draft resumes for its own account while fresh, never another', () {
      final now = DateTime.utc(2026, 9, 26, 12);
      final raw = CreationDraft(userId: 'user-1', savedAt: now, intent: intent)
          .encode();
      expect(raw, isNot(contains('password')));
      final back = CreationDraft.decodeFor(raw, userId: 'user-1', now: now);
      expect(back?.intent.requestId, intent.requestId);
      expect(back?.intent.sameMaterial(intent), isTrue);
      expect(CreationDraft.decodeFor(raw, userId: 'user-2', now: now), isNull);
      expect(CreationDraft.decodeFor(raw, userId: null, now: now), isNull);
      expect(
        CreationDraft.decodeFor(raw,
            userId: 'user-1', now: now.add(const Duration(days: 8))),
        isNull,
      );
      expect(CreationDraft.decodeFor('{nope', userId: 'user-1', now: now),
          isNull);
    });
  });

  testWidgets('one test workspace is the default, and the confirm step '
      'says how many, where and whether it bills', (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await goTo(tester, 'Confirm');
    expect(find.text('Creates one workspace'), findsOneWidget);
    expect(find.textContaining('No real billing'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-summary-server')),
        findsOneWidget);
    await pressCreate(tester);
    expect(repo.createRequests.single.withTwin, isFalse);
    expect(repo.workspaces.single.environment, 'dev');
  });

  testWidgets('a real workspace is chosen, not defaulted, and says it bills',
      (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await goTo(tester, 'Where');
    await tapKey(tester, 'onboarding-shape-real');
    await goTo(tester, 'Confirm');
    expect(find.textContaining('Real billing is possible'), findsOneWidget);
    await pressCreate(tester);
    expect(repo.workspaces.single.environment, 'prod');
    expect(repo.createRequests.single.withTwin, isFalse);
  });

  testWidgets('a country change keeps a currency the owner chose, and '
      'follows the one they did not touch', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await goTo(tester, 'Where');
    await tester.enterText(
        find.byKey(const ValueKey('onboarding-currency')), 'CHF');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('France').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('onboarding-currency')))
            .controller!
            .text,
        'CHF',
        reason: 'the owner typed it');
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('onboarding-timezone')))
            .controller!
            .text,
        'Europe/Paris',
        reason: 'the zone was still the derived one');
  });

  testWidgets('an unknown currency or zone is refused on the field',
      (tester) async {
    final repo = await pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await goTo(tester, 'Where');
    await tester.enterText(
        find.byKey(const ValueKey('onboarding-currency')), 'EURO');
    await tester.enterText(
        find.byKey(const ValueKey('onboarding-timezone')), 'Europe/Pairs');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('currency code the app supports'), findsOneWidget);
    expect(find.text('Pick a time zone from the list'), findsOneWidget);
    expect(repo.createRequests, isEmpty);
  });

  testWidgets('after a lost response the form is frozen: an edit is held '
      'back, and Retry as sent sends the same request unchanged',
      (tester) async {
    final repo = await pump(tester)
      ..createFailure = StateError('the response was lost');
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await goTo(tester, 'Confirm');
    await pressCreate(tester);
    expect(repo.workspaces, isEmpty);
    expect(find.byKey(const ValueKey('onboarding-create-without-template')),
        findsNothing, reason: 'a lost response is not a template refusal');
    expect(find.byKey(const ValueKey('onboarding-intent-pending')),
        findsOneWidget);

    // The owner changes the shape and presses Create: nothing is sent.
    await goTo(tester, 'Where');
    await tapKey(tester, 'onboarding-shape-pair');
    await goTo(tester, 'Confirm');
    await pressCreate(tester);
    expect(repo.createRequests, hasLength(1), reason: 'held back');
    expect(find.textContaining('Retry it exactly as it was sent'),
        findsOneWidget);

    await tapKey(tester, 'onboarding-intent-pending');
    await tester.tap(find.text('Retry as sent'));
    await tester.pumpAndSettle();
    expect(repo.createRequests, hasLength(2));
    expect(repo.createRequests.last.withTwin, isFalse,
        reason: 'sent as it was, not as edited');
    expect({for (final r in repo.createRequests) r.requestId}, hasLength(1));
    expect(repo.workspaces, hasLength(1));
  });

  testWidgets('a restart resumes the pending request for the same account',
      (tester) async {
    final drafts = InMemoryCreationDraftStore(CreationDraft(
      userId: 'user-1',
      savedAt: kTestNow,
      intent: intent,
    ).encode());
    final repo = await pump(tester, drafts: drafts);
    expect(find.byKey(const ValueKey('onboarding-confirm')), findsOneWidget);
    expect(find.textContaining('An earlier creation may have gone through'),
        findsOneWidget);
    await pressCreate(tester);
    expect(repo.createRequests.single.requestId, intent.requestId);
    expect(drafts.value, isNull, reason: 'confirmed, so forgotten');
  });

  testWidgets('another account\'s draft is neither resumed nor shown',
      (tester) async {
    final drafts = InMemoryCreationDraftStore(CreationDraft(
      userId: 'someone-else',
      savedAt: kTestNow,
      intent: intent,
    ).encode());
    await pump(tester, drafts: drafts);
    expect(find.byKey(const ValueKey('onboarding-confirm')), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-intent-pending')),
        findsNothing);
  });
}
