// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — the level table holds together: every selectable
// feature belongs to exactly one level, a level never needs a feature only
// a higher level or an undeclared process brings, the presets nest and meet
// their needs, and no answer the owner can give yields a vector that
// cannot be applied.
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final homes = <WorkspaceFeature, List<String>>{};
  for (final MapEntry(key: process, value: levels) in setupLevels.entries) {
    for (final level in levels) {
      for (final f in level.features) {
        (homes[f] ??= []).add('${process.name}.${level.id}');
      }
    }
  }

  test('every selectable feature belongs to exactly one level', () {
    final missing = [
      for (final f in WorkspaceFeature.values)
        if (!homes.containsKey(f) && !internalCapabilities.containsKey(f))
          f.name,
    ];
    final twice = [
      for (final MapEntry(:key, :value) in homes.entries)
        if (value.length > 1) '${key.name}: ${value.join(', ')}',
    ];
    expect(missing, isEmpty, reason: 'give each a level in setup_levels.dart');
    expect(twice, isEmpty);
  });

  test('a level\'s features find their parents at or below it, or in a '
      'level it declares it needs', () {
    final problems = <String>[];
    for (final MapEntry(key: process, value: levels) in setupLevels.entries) {
      for (final (rank, level) in levels.indexed) {
        final reachable = {
          for (final l in levels.take(rank + 1)) ...l.features,
          for (final lower in levels.take(rank + 1))
            for (final MapEntry(key: other, value: minimum)
                in lower.needs.entries)
              for (final l in setupLevels[other]!.take(
                setupLevelRank(other, minimum) + 1,
              ))
                ...l.features,
        };
        for (final f in level.features) {
          final parent = featureManifest[f]?.requires;
          if (parent != null &&
              homes.containsKey(parent) &&
              !reachable.contains(parent)) {
            problems.add(
              '${process.name}.${level.id}: ${f.name} needs '
              '${parent.name} (${homes[parent]!.join(', ')})',
            );
          }
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('the presets name every process, meet their needs and nest', () {
    for (final MapEntry(key: preset, value: vector) in setupPresets.entries) {
      expect(
        vector.keys.toSet(),
        SetupProcess.values.toSet(),
        reason: preset.name,
      );
      expect(setupVectorGaps(vector), isEmpty, reason: preset.name);
    }
    for (final process in SetupProcess.values) {
      final ranks = [
        for (final p in SetupPreset.values)
          setupLevelRank(process, setupPresets[p]![process]!),
      ];
      expect(
        ranks,
        orderedEquals([...ranks]..sort()),
        reason: '${process.name}: essentiel ≤ standard ≤ complet',
      );
    }
  });

  test('Essentiel keeps statements and never invoices or VAT', () {
    final delta = setupFeatureDelta(setupPresets[SetupPreset.essentiel]!);
    expect(delta.on, contains(WorkspaceFeature.moneyTab));
    expect(
      delta.off,
      containsAll([WorkspaceFeature.invoicing, WorkspaceFeature.vatManagement]),
    );
  });

  test('every answer the owner can give yields a vector without a gap', () {
    for (var bits = 0; bits < 1 << 10; bits++) {
      bool bit(int i) => bits & (1 << i) != 0;
      final answers = SetupAnswers(
        membersOweMoney: bit(0),
        issueInvoices: bit(1),
        payOnline: bit(2),
        vatRegistered: bit(3),
        keepBooks: bit(4),
        tracksPurchases: bit(5),
        severalRoomsOrSites: bit(6),
        doorTablet: bit(7),
        publicPage: bit(8),
        organised: bit(9),
      );
      final recommended = recommendSetupLevels(answers);
      expect(recommended.keys.toSet(), SetupProcess.values.toSet());
      final vector = {
        for (final MapEntry(:key, :value) in recommended.entries)
          key: value.level,
      };
      expect(setupVectorGaps(vector), isEmpty, reason: '$bits');
      expect(
        vector.entries.every((e) => setupLevelRank(e.key, e.value) >= 0),
        isTrue,
      );
    }
  });

  test('lowering a level turns off exactly what it had added', () {
    final standard = setupFeatureDelta(setupPresets[SetupPreset.standard]!);
    final lowered = setupFeatureDelta({
      ...setupPresets[SetupPreset.standard]!,
      SetupProcess.money: 'statements',
    });
    expect(
      lowered.off.difference(standard.off),
      setupLevels[SetupProcess.money]![2].features,
    );
  });
}
