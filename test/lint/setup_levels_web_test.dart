// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — the questions step of `web/setup.html` asks the levels screen's
// questions and runs its rules. The rules travel as data
// (`web/setup_catalogue.js`, drift-gated by setup_l10n_test), but the page
// evaluates them in its own JavaScript, and an evaluator can drift while
// the data stays the same. So the page is driven through every answer an
// owner can give (`tool/setup/step_harness.mjs --recommend-all`) and each
// result is compared with `recommendSetupLevels` and with the switches
// `setupFeatureDelta` would set: the page recommends, and ticks, exactly
// what the app would.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the page recommends and ticks what setup_levels.dart does, for '
      'every combination of answers', () {
    if (Process.runSync('node', ['--version']).exitCode != 0) {
      markTestSkipped('node is not on PATH');
      return;
    }
    final r = Process.runSync('node', [
      'tool/setup/step_harness.mjs',
      '--recommend-all',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = jsonDecode('${r.stdout}') as Map<String, dynamic>;
    final initial = (out['initial'] as List).cast<String>().toSet();
    final combos = out['combos'] as List;
    expect(combos, hasLength(1 << setupQuestions.length));
    final wrong = <String>[];
    for (final combo in combos.cast<Map<String, dynamic>>()) {
      final bits = combo['bits'] as int;
      final recommended = recommendSetupLevels(
        SetupAnswers.fromJson({
          for (final (i, q) in setupQuestions.indexed) q: bits & (1 << i) != 0,
        }),
      );
      final vector = {
        for (final MapEntry(:key, :value) in recommended.entries)
          key: value.level,
      };
      final delta = setupFeatureDelta(vector);
      final on = {...initial}
        ..removeAll(delta.off.map((f) => f.name))
        ..addAll(delta.on.map((f) => f.name));
      final same =
          jsonEncode(combo['recommended']) ==
              jsonEncode({
                for (final MapEntry(:key, :value) in recommended.entries)
                  key.name: '${value.level}/${value.reason}',
              }) &&
          jsonEncode(combo['levels']) ==
              jsonEncode({
                for (final MapEntry(:key, :value) in vector.entries)
                  key.name: value,
              }) &&
          (combo['on'] as List).cast<String>().toSet().containsAll(on) &&
          on.containsAll((combo['on'] as List).cast<String>());
      if (!same) wrong.add('answers $bits: ${jsonEncode(combo)}');
    }
    expect(wrong, isEmpty, reason: wrong.take(3).join('\n'));
  });
}
