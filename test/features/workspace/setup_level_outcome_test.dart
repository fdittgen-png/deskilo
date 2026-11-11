// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3283 — before Apply, the review says in plain words what the business
// will be able to do: one sentence per level, kept beside the level's name
// (`setupLevelOutcome('<process>_<id>')`), in every language, ahead of the
// exact switches.
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/presentation/widgets/setup_level_preview.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every level of every process has its own sentence in five languages',
    () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        final seen = <String>{};
        setupLevels.forEach((process, levels) {
          for (final level in levels) {
            final key = '${process.name}_${level.id}';
            final sentence = l10n.setupLevelOutcome(key);
            expect(
              sentence,
              isNot(key),
              reason: '$locale $key has no sentence',
            );
            expect(
              seen.add(sentence),
              isTrue,
              reason: '$locale $key repeats another level',
            );
          }
        });
      }
    },
  );

  testWidgets('the review leads with what the changed level lets the business '
      'do', (tester) async {
    final vector = setupPresets[SetupPreset.essentiel]!;
    final on = setupFeatureDelta(vector).on;
    final current = currentSetupLevels(on);
    final change = planSetupLevels(
      stored: on,
      current: current,
      chosen: {...current, SetupProcess.money: 'invoices'},
    );
    expect(change.levels, {SetupProcess.money: 'invoices'});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: SetupLevelPreview(change: change)),
        ),
      ),
    );
    final outcome = find.byKey(const ValueKey('setup-levels-outcome-money'));
    expect(outcome, findsOneWidget);
    expect(
      find.descendant(
        of: outcome,
        matching: find.textContaining(
          'You will be able to issue numbered '
          'invoices',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(outcome).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('setup-levels-details')))
            .dy,
      ),
      reason: 'the plain sentence comes before the folded exact switches',
    );
  });

  test('nothing to change says nothing about outcomes', () {
    final vector = setupPresets[SetupPreset.standard]!;
    final on = setupFeatureDelta(vector).on;
    final change = planSetupLevels(
      stored: on,
      current: currentSetupLevels(on),
      chosen: vector,
    );
    expect(change.levels, isEmpty);
  });
}
