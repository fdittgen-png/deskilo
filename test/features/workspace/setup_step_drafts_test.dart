// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2869 — the step pages whose form holds answers the owner has not saved
// keep them as the step's draft on the server, as the basics page does
// (setup_basics_draft_test): the colour (look), how members pay, the
// levels offered (pricing), the legal identity and the public page. On
// each: an edit left unsaved is on the server once the page is left;
// reopening it (a fresh scope: what another device would see) puts it
// back over the stored values with "Draft restored"; Save applies it and
// drops the draft. The pricing, legal identity and public page belong to
// features above the workspace and get the draft through the frame the
// step screen hands in, so these run them as the router composes them.
import 'package:deskilo/app/routes/setup_grow_pages.dart';
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/data/public_directory_repository.dart';
import 'package:deskilo/features/money/domain/subscription_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_step_draft.dart';
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 3200);

/// The fakes a page reads and writes; they outlive each opening.
class _Space {
  final server = FakeLocalSetupRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace();
  final money = FakeMoneyRepository()
    ..subscriptionLevels = const SubscriptionLevels(enabledPresets: [50, 100]);
  final directory = FakeDirectoryRepository()
    ..ownName = 'Test Space'
    ..pages['ws-1'] = {
      'published': false,
      'document': <String, dynamic>{
        'host_type': 'company',
        'description': 'Desks by the sea',
      },
    };

  Future<SetupStepDraft?> draft(String step) => server.stepDraft('ws-1', step);
}

Future<void> _open(WidgetTester tester, _Space space, String step) async {
  await pumpApp(
    tester,
    SetupStepScreen(
      stepId: step,
      runPages: setupRunPages,
      growPages: setupGrowPages,
    ),
    size: _phone,
    overrides: standardTestOverrides(
      workspace: space.workspace,
      money: space.money,
      directory: space.directory,
      localSetup: space.server,
    ),
  );
  await tester.pumpAndSettle();
}

/// Leaves the page before the autosave pause: its scope goes, as when
/// the app is closed, and what is pending is still sent.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
  matchRoot: true,
);

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(_field(key)).controller!.text;

final _restored = find.byKey(const ValueKey('setup-draft-restored'));

/// Edit, leave, reopen: the edit is back over the stored value, said so;
/// Save applies it and drops the draft.
Future<void> _roundTrip(
  WidgetTester tester, {
  required _Space space,
  required String step,
  required Future<void> Function() edit,
  required void Function() expectEdited,
  required String save,
}) async {
  await _open(tester, space, step);
  expect(_restored, findsNothing);
  await edit();
  await _leave(tester);
  expect(await space.draft(step), isNotNull, reason: 'kept on the server');

  await _open(tester, space, step);
  expect(_restored, findsOneWidget);
  expectEdited();

  await _save(tester, save);
  expect(await space.draft(step), isNull, reason: 'applied, not a draft');
  expect(_restored, findsNothing);
}

void main() {
  testWidgets('look: a colour picked and not saved comes back', (tester) async {
    final space = _Space();
    await _roundTrip(
      tester,
      space: space,
      step: 'look',
      edit: () async {
        await tester.tap(find.byKey(const ValueKey('setup-look-pick-#1B5E20')));
        await tester.pump();
      },
      expectEdited: () => expect(_text(tester, 'setup-look-hex'), '#1B5E20'),
      save: 'setup-look-save',
    );
    expect(
      space.workspace.workspaces.first.branding[BrandingKeys.seedColor],
      '#1B5E20',
    );
  });

  testWidgets('how members pay: details typed and not saved come back', (
    tester,
  ) async {
    final space = _Space();
    await _roundTrip(
      tester,
      space: space,
      step: 'payment_methods',
      edit: () async {
        await tester.enterText(
          find.byKey(const Key('workspaceSettingsWero')),
          '+33 6 12 34 56 78',
        );
        await tester.pump();
      },
      expectEdited: () => expect(
        tester
            .widget<TextField>(find.byKey(const Key('workspaceSettingsWero')))
            .controller!
            .text,
        '+33 6 12 34 56 78',
      ),
      save: 'setup-payments-save',
    );
    expect(
      space.workspace.workspaces.first.paymentInstructions['wero'],
      '+33 6 12 34 56 78',
    );
  });

  testWidgets('pricing: a level picked and not offered comes back', (
    tester,
  ) async {
    final space = _Space();
    bool chip(int preset) => tester
        .widget<FilterChip>(find.byKey(ValueKey('setup-pricing-level-$preset')))
        .selected;
    await _roundTrip(
      tester,
      space: space,
      step: 'pricing',
      edit: () async {
        await tester.tap(find.byKey(const ValueKey('setup-pricing-level-25')));
        await tester.pump();
      },
      expectEdited: () => expect(chip(25), isTrue),
      save: 'setup-pricing-offer',
    );
    expect(space.money.subscriptionLevels.enabledPresets, contains(25));
  });

  testWidgets('legal identity: words typed and not saved come back', (
    tester,
  ) async {
    final space = _Space();
    await _roundTrip(
      tester,
      space: space,
      step: 'legal_identity',
      edit: () async {
        await tester.enterText(_field('setup-legal-form'), 'SARL');
        await tester.pump();
      },
      expectEdited: () => expect(_text(tester, 'setup-legal-form'), 'SARL'),
      save: 'setup-legal-save',
    );
    expect(space.workspace.workspaces.first.invoiceLegal['legal_form'], 'SARL');
  });

  testWidgets('public page: words typed and not saved come back', (
    tester,
  ) async {
    final space = _Space();
    await _roundTrip(
      tester,
      space: space,
      step: 'public_page',
      edit: () async {
        await tester.enterText(
          _field('setup-public-page-description'),
          'Quiet desks, fast wifi',
        );
        await tester.pump();
      },
      expectEdited: () => expect(
        _text(tester, 'setup-public-page-description'),
        'Quiet desks, fast wifi',
      ),
      save: 'setup-public-page-save',
    );
    final page = space.directory.pages['ws-1']!;
    expect((page['document']! as Map)['description'], 'Quiet desks, fast wifi');
  });

  testWidgets('Discard on a restored page puts the stored value back', (
    tester,
  ) async {
    final space = _Space();
    await space.server.saveStepDraft(
      'ws-1',
      'legal_identity',
      payload: {'vat_regime': 'not_subject', 'legalForm': 'SAS'},
      expectedVersion: null,
      requestId: 'seed',
    );
    await _open(tester, space, 'legal_identity');
    expect(_text(tester, 'setup-legal-form'), 'SAS');

    await tester.tap(find.byKey(const ValueKey('setup-draft-discard')));
    await tester.pump();
    await tester.pump();
    expect(await space.draft('legal_identity'), isNull);
    expect(_text(tester, 'setup-legal-form'), isNot('SAS'));
  });
}
