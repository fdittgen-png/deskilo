// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3300 — the setup guide never switches on a feature the space's country
// does not offer (MTD submission outside the United Kingdom), never holds a
// level back for it, and keeps its stored switch as it is.
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stored = resolveEnabledFeatures(const {});
  SetupLevelChange books(String country, {Set<WorkspaceFeature>? from}) {
    final s = from ?? stored;
    final current = currentSetupLevels(s, country: country);
    return planSetupLevels(
      stored: s,
      current: current,
      chosen: {...current, SetupProcess.tax: 'books'},
      country: country,
    );
  }

  for (final country in ['FR', 'DE', 'US']) {
    test('the books level does not switch MTD submission on in $country', () {
      final change = books(country);
      expect(change.switchOn, isNot(contains(WorkspaceFeature.mtdSubmission)));
      expect(change.switchOn, contains(WorkspaceFeature.accountingBook));
    });

    test('in $country the books level is reached without MTD submission', () {
      final on = {...stored, ...books(country).switchOn};
      expect(currentSetupLevels(on, country: country)[SetupProcess.tax], 'books');
    });

    test('in $country a lower level leaves a stored MTD switch as it is', () {
      final on = {...stored, ...books(country).switchOn, WorkspaceFeature.mtdSubmission};
      final current = currentSetupLevels(on, country: country);
      final down = planSetupLevels(
        stored: on,
        current: current,
        chosen: {...current, SetupProcess.tax: setupLevels[SetupProcess.tax]!.first.id},
        country: country,
      );
      expect(down.switchOff, isNot(contains(WorkspaceFeature.mtdSubmission)));
    });
  }

  test('in the United Kingdom the books level switches MTD submission on', () {
    expect(books('GB').switchOn, contains(WorkspaceFeature.mtdSubmission));
  });
}
