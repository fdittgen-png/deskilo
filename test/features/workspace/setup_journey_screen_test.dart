// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the levels screen remembers: applying stores the answers and the
// levels on the server, and the screen opens with them again (any device
// reads the same store); answers someone else saved meanwhile are shown,
// never overwritten; and beside the questions stands what the law of the
// space's country asks, from the tax reference data, with "ask your
// accountant" where nobody confirmed it.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeLocalSetupRepository local,
  FakeWorkspaceRepository workspace,
) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const SetupLevelsScreen(),
    overrides: standardTestOverrides(workspace: workspace, localSetup: local),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

/// Applies, saying yes when switching something off asks first.
Future<void> _apply(WidgetTester tester) async {
  await _tap(tester, 'setup-levels-apply');
  if (find.byKey(const ValueKey('setup-levels-confirm-off-yes')).evaluate()
      case [_, ...]) {
    await _tap(tester, 'setup-levels-confirm-off-yes');
  }
}

bool _answer(WidgetTester tester, String question) => tester
    .widget<SwitchListTile>(find.byKey(ValueKey('setup-question-$question')))
    .value;

void main() {
  testWidgets('applying remembers the answers and the levels, and the '
      'screen opens with them again', (tester) async {
    final local = FakeLocalSetupRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await _pump(tester, local, workspace);
    expect(_answer(tester, 'issue_invoices'), isFalse);

    await _tap(tester, 'setup-question-issue_invoices');
    await _apply(tester);

    final saved = (await local.setupJourney('ws-1'))!;
    expect(saved.version, 1);
    expect(saved.answers, const SetupAnswers(issueInvoices: true));
    expect(saved.levels, {
      for (final MapEntry(:key, :value) in recommendSetupLevels(
        const SetupAnswers(issueInvoices: true),
      ).entries)
        key: value.level,
    });

    await _pump(tester, local, workspace);
    expect(_answer(tester, 'issue_invoices'), isTrue);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('setup-levels-apply')),
          )
          .onPressed,
      isNull,
      reason: 'reopened, nothing is left to apply',
    );
  });

  testWidgets('answers someone else saved meanwhile are shown, never '
      'overwritten', (tester) async {
    final local = FakeLocalSetupRepository();
    await local.saveSetupJourney(
      'ws-1',
      answers: const SetupAnswers(organised: true),
      levels: const {},
      expectedVersion: null,
      requestId: 'first',
    );
    await _pump(tester, local, FakeWorkspaceRepository.withWorkspace());
    expect(_answer(tester, 'organised'), isTrue);

    // Another device saves while this one is answering.
    await local.saveSetupJourney(
      'ws-1',
      answers: const SetupAnswers(publicPage: true),
      levels: const {},
      expectedVersion: 1,
      requestId: 'other-device',
    );
    await _tap(tester, 'setup-question-door_tablet');
    await _apply(tester);

    expect(
      find.text(
        'Someone else saved other answers meanwhile. Here they are: look '
        'again, then apply.',
      ),
      findsOneWidget,
    );
    final stored = (await local.setupJourney('ws-1'))!;
    expect(stored.version, 2);
    expect(stored.answers, const SetupAnswers(publicPage: true));
    expect(_answer(tester, 'public_page'), isTrue);
    expect(_answer(tester, 'door_tablet'), isFalse);
  });

  testWidgets('beside the questions, what the law of the country asks, '
      'with its source and "ask your accountant" where unconfirmed', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeLocalSetupRepository(),
      FakeWorkspaceRepository.withWorkspace(),
    );
    final card = find.byKey(const ValueKey('setup-obligations'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text('What the law asks in Germany'),
      ),
      findsOneWidget,
    );
    // The bundled German rows: dated e-invoicing duties nobody confirmed,
    // and the confirmed small-business limits.
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(
          'Not confirmed for this country — ask your accountant.',
        ),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining('The small-business VAT exemption'),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Source: ')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('setup-obligations-none')), findsNothing);
  });
}
