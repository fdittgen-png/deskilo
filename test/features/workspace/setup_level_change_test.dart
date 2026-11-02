// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — a level change touches only the processes whose level changes:
// the current levels read back from the features a choice turned on, a
// choice equal to the current one writes nothing, and a recommendation
// below what a process already uses never switches it off unless that
// process was changed.
import 'package:deskilo/features/workspace/domain/setup_level_change.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the levels a preset turns on read back as that preset', () {
    for (final preset in SetupPreset.values) {
      final vector = setupPresets[preset]!;
      final on = setupFeatureDelta(vector).on;
      expect(currentSetupLevels(on), vector, reason: preset.name);
    }
  });

  test('choosing what is already there writes nothing', () {
    final vector = setupPresets[SetupPreset.standard]!;
    final on = setupFeatureDelta(vector).on;
    final change = planSetupLevels(
      stored: on,
      current: currentSetupLevels(on),
      chosen: vector,
    );
    expect(change.isEmpty, isTrue);
    expect(change.processes, isEmpty);
  });

  test('raising one process switches on only its features, with the '
      'read-set of what it rests on', () {
    final vector = setupPresets[SetupPreset.essentiel]!;
    final on = setupFeatureDelta(vector).on;
    final current = currentSetupLevels(on);
    final chosen = {...current, SetupProcess.money: 'invoices'};
    final change = planSetupLevels(
      stored: on,
      current: current,
      chosen: chosen,
    );
    expect(change.processes, {SetupProcess.money});
    final invoices = setupLevels[SetupProcess.money]!.last.features;
    expect(change.switchOn.toSet(), invoices.difference(on));
    expect(change.switchOff, isEmpty);
    expect(change.flags.values, everyElement(isTrue));
    expect(change.expected.values, everyElement(isFalse));
  });

  test('lowering one process switches off its features and leaves every '
      'other process as it is', () {
    final vector = setupPresets[SetupPreset.complet]!;
    final on = setupFeatureDelta(vector).on;
    final current = currentSetupLevels(on);
    final chosen = {...current, SetupProcess.tax: 'none'};
    final change = planSetupLevels(
      stored: on,
      current: current,
      chosen: chosen,
    );
    expect(change.processes, {SetupProcess.tax});
    final taxFeatures = {
      for (final l in setupLevels[SetupProcess.tax]!) ...l.features,
    };
    expect(change.switchOff.toSet(), taxFeatures.intersection(on));
    expect(change.switchOn, isEmpty);
  });
}
