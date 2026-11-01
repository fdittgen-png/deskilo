// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3076 — the questions open from what the space already does: a switch is
// on where the current levels say so, before the owner touches anything,
// and nothing is planned until an answer changes. "Not sure yet" is a third
// answer: it keeps the safe level and says which processes stay there.
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_levels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

/// The feature flags of a space that does [vector] (the rest at the
/// defaults).
Map<String, dynamic> _flagsFor(SetupLevelVector vector) {
  final stored = resolveEnabledFeatures(const {});
  final current = currentSetupLevels(stored);
  return planSetupLevels(
    stored: stored,
    current: current,
    chosen: {...current, ...vector},
  ).flags;
}

Future<void> _pump(WidgetTester tester, Map<String, dynamic> flags) async {
  tester.view.physicalSize = const Size(900, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    const SetupLevelsScreen(),
    overrides: standardTestOverrides(
      workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
    ),
  );
  await tester.pumpAndSettle();
}

bool _on(WidgetTester tester, String question) => tester
    .widget<SwitchListTile>(find.byKey(ValueKey('setup-question-$question')))
    .value;

void main() {
  test('the answers a vector of levels stands for', () {
    final answers = setupAnswersFromLevels({
      SetupProcess.bookings: 'resources',
      SetupProcess.community: 'organised',
      SetupProcess.money: 'invoices',
      SetupProcess.payments: 'off',
      SetupProcess.tax: 'vat',
      SetupProcess.purchases: 'none',
      SetupProcess.presentation: 'basic',
    });
    expect(
      {
        for (final q in setupQuestions)
          if (answers[q]) q,
      },
      {
        'members_owe_money',
        'issue_invoices',
        'vat_registered',
        'several_rooms_or_sites',
        'organised',
      },
    );
  });

  testWidgets('a configured space opens with its questions answered', (
    tester,
  ) async {
    await _pump(
      tester,
      _flagsFor({
        SetupProcess.money: 'invoices',
        SetupProcess.tax: 'vat',
        SetupProcess.bookings: 'resources',
      }),
    );
    expect(_on(tester, 'issue_invoices'), isTrue);
    expect(_on(tester, 'vat_registered'), isTrue);
    expect(_on(tester, 'several_rooms_or_sites'), isTrue);
    expect(_on(tester, 'keep_books'), isFalse);
    expect(_on(tester, 'pay_online'), isFalse);
    // Nothing is asked to change before an answer does.
    expect(
      find.text('Nothing changes: the space already does this.'),
      findsOneWidget,
    );
  });

  testWidgets('"not sure yet" keeps the safe level and says what stays there', (
    tester,
  ) async {
    await _pump(tester, const {});
    await tester.tap(
      find.byKey(const ValueKey('setup-question-pay_online-unknown')),
    );
    await tester.pumpAndSettle();
    expect(_on(tester, 'pay_online'), isFalse);
    final note = tester.widget<Text>(
      find.byKey(const ValueKey('setup-question-pay_online-note')),
    );
    expect(note.data, contains('Payments'));
    expect(note.data, contains('By transfer'));
    // Answering for real replaces the note.
    await tester.tap(find.byKey(const ValueKey('setup-question-pay_online')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('setup-question-pay_online-note')),
      findsNothing,
    );
  });
}
