// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — the basics step announces the country and currency lock before
// saving. Once the space has issued a document or recorded money (0399's
// guard) both show as stored whatever a draft held, cannot be picked, say
// why, and Save sends the stored pair. Before that, saving a new country
// or currency first names what will become fixed: Cancel saves nothing,
// Save stores it; the stored pair saves without asking.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

/// A draft another visit left: France, still in euros.
Future<FakeLocalSetupRepository> _franceDraft() async {
  final server = FakeLocalSetupRepository();
  await server.saveStepDraft(
    'ws-1',
    'basics',
    payload: {
      'country_code': 'FR',
      'currency_code': 'EUR',
      'timezone': 'Europe/Berlin',
      'language': '',
    },
    expectedVersion: null,
    requestId: 'seed',
  );
  return server;
}

Future<FakeWorkspaceRepository> _open(
  WidgetTester tester, {
  required bool moneyRecorded,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  await pumpApp(
    tester,
    SetupStepScreen(stepId: 'basics', moneyRecorded: (_, _) => moneyRecorded),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: workspace,
      localSetup: await _franceDraft(),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('setup-basics-save')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

DropdownButton<String> _picker(WidgetTester tester, Finder field) =>
    tester.widget<DropdownButton<String>>(
      find.descendant(of: field, matching: find.byType(DropdownButton<String>)),
    );

void main() {
  testWidgets('fixed after money: the stored country and currency show, '
      'cannot be picked, say why, and Save keeps them', (tester) async {
    final workspace = await _open(tester, moneyRecorded: true);
    final country = find.byKey(const ValueKey('setup-basics-country-DE'));
    expect(country, findsOneWidget, reason: 'the draft\'s France gives way');
    expect(_picker(tester, country).onChanged, isNull);
    expect(
      _picker(
        tester,
        find.byKey(const Key('workspaceSettingsCurrency')),
      ).onChanged,
      isNull,
    );
    expect(
      find.text(
        'Fixed: this space has already issued a document or recorded money, '
        'so the country and the currency can no longer change.',
      ),
      findsOneWidget,
    );

    await _save(tester);
    expect(find.byKey(const ValueKey('lock-confirm-body')), findsNothing);
    expect(workspace.lastLocaleUpdate, ['ws-1', 'DE', 'EUR', 'Europe/Berlin']);
  });

  testWidgets('before money: a new country is confirmed before it is saved, '
      'and Cancel saves nothing', (tester) async {
    final workspace = await _open(tester, moneyRecorded: false);
    final country = find.byKey(const ValueKey('setup-basics-country-FR'));
    expect(country, findsOneWidget, reason: 'the draft is back');
    expect(_picker(tester, country).onChanged, isNotNull);

    await _save(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('lock-confirm-body'))).data,
      'France and EUR become fixed for good once this space issues a document '
      'or records money: after that, neither can change. Check them with your '
      'accountant if you are unsure.',
    );
    await tester.tap(find.byKey(const ValueKey('lock-confirm-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(workspace.lastLocaleUpdate, isNull, reason: 'nothing saved');

    await _save(tester);
    await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
    await tester.pumpAndSettle();
    expect(workspace.lastLocaleUpdate, ['ws-1', 'FR', 'EUR', 'Europe/Berlin']);
  });
}
