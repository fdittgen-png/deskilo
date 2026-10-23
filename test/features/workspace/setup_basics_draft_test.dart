// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — the basics step keeps what the owner picked and did not save as
// a draft on the server. Leaving the page and opening it again (a fresh
// scope: what another device would see) puts the draft back over the
// stored values with "Draft restored · Discard"; Discard drops it and
// shows the stored values; Save applies the answers and drops the draft;
// a draft another configurer changed meanwhile shows "Reload" and "Keep
// mine", and keep mine writes against their version. Every case reads the
// fake server's stored draft.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/ui/app_durations.dart';
import 'package:deskilo/features/workspace/domain/setup_step_draft.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Future<void> _open(
  WidgetTester tester,
  FakeLocalSetupRepository server, {
  FakeWorkspaceRepository? workspace,
}) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'basics'),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: workspace ?? FakeWorkspaceRepository.withWorkspace(),
      localSetup: server,
    ),
  );
  await tester.pumpAndSettle();
}

/// Leaves the page: its scope goes, as when the app is closed.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pickLanguage(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('setup-basics-language')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pump();
}

Future<SetupStepDraft?> _stored(FakeLocalSetupRepository server) =>
    server.stepDraft('ws-1', 'basics');

Future<void> _seed(
  FakeLocalSetupRepository server,
  String language, {
  int? expected,
  String requestId = 'seed',
}) => server.saveStepDraft(
  'ws-1',
  'basics',
  payload: {
    'country_code': 'DE',
    'currency_code': 'EUR',
    'timezone': 'Europe/Berlin',
    'language': language,
  },
  expectedVersion: expected,
  requestId: requestId,
);

Finder _shown(String name) => find.descendant(
  of: find.byKey(const ValueKey('setup-basics-language')),
  matching: find.text(name),
);

void main() {
  testWidgets('a pick left unsaved comes back after leaving and reopening', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository();
    await _open(tester, server);
    expect(find.byKey(const ValueKey('setup-draft-restored')), findsNothing);

    await _pickLanguage(tester, 'Français');
    // Leaves before the pause: what is pending is still sent.
    await _leave(tester);
    expect((await _stored(server))?.payload['language'], 'fr');

    await _open(tester, server);
    expect(find.byKey(const ValueKey('setup-draft-restored')), findsOneWidget);
    expect(_shown('Français'), findsOneWidget);
  });

  testWidgets('the status says saved once the server answered', (tester) async {
    final server = FakeLocalSetupRepository();
    await _open(tester, server);
    await _pickLanguage(tester, 'Italiano');
    await tester.pump(AppDurations.draftAutosave);
    await tester.pump();
    expect(find.text('Draft saved'), findsOneWidget);
    expect((await _stored(server))?.payload['language'], 'it');
  });

  testWidgets('Discard drops the draft and shows the stored values', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository();
    await _seed(server, 'fr');
    await _open(tester, server);
    expect(_shown('Français'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('setup-draft-discard')));
    await tester.pump();
    await tester.pump();
    expect(await _stored(server), isNull);
    expect(find.byKey(const ValueKey('setup-draft-restored')), findsNothing);
    expect(_shown('Français'), findsNothing);
  });

  testWidgets('Save applies the answers and drops the draft', (tester) async {
    final server = FakeLocalSetupRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await _seed(server, 'fr');
    await _open(tester, server, workspace: workspace);

    await tester.tap(find.byKey(const ValueKey('setup-basics-save')));
    await tester.pumpAndSettle();
    expect(workspace.workspaces.first.defaultLocale, 'fr');
    expect(await _stored(server), isNull);
    expect(find.byKey(const ValueKey('setup-draft-restored')), findsNothing);
  });

  testWidgets('a draft changed by someone else offers reload and keep mine; '
      'keep mine saves over their version', (tester) async {
    final server = FakeLocalSetupRepository();
    await _seed(server, 'fr');
    await _open(tester, server);
    // Another configurer saves over version 1 meanwhile.
    await _seed(server, 'de', expected: 1, requestId: 'other');

    await _pickLanguage(tester, 'Español');
    await tester.pump(AppDurations.draftAutosave);
    await tester.pump();
    expect(find.byKey(const ValueKey('setup-draft-conflict')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-draft-reload')), findsOneWidget);
    expect(
      (await _stored(server))?.payload['language'],
      'de',
      reason: 'their draft is not overwritten',
    );

    await tester.tap(find.byKey(const ValueKey('setup-draft-keep-mine')));
    await tester.pump();
    await tester.pump();
    final stored = await _stored(server);
    expect(stored?.payload['language'], 'es');
    expect(stored?.version, 3);
    expect(find.byKey(const ValueKey('setup-draft-conflict')), findsNothing);
  });

  testWidgets('reload shows their answers and keeps their draft', (
    tester,
  ) async {
    final server = FakeLocalSetupRepository();
    await _seed(server, 'fr');
    await _open(tester, server);
    await _seed(server, 'de', expected: 1, requestId: 'other');

    await _pickLanguage(tester, 'Español');
    await tester.pump(AppDurations.draftAutosave);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup-draft-reload')));
    await tester.pump();
    expect(_shown('Deutsch'), findsOneWidget);
    final stored = await _stored(server);
    expect(stored?.payload['language'], 'de');
    expect(stored?.version, 2);
  });
}
