// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup levels have one home, `setup_levels.dart`. The server's copy,
// `setup_level_catalogue()`, is generated from it, and the MCP contract's
// choices are the same table: every process with exactly its levels, the
// presets by name, and the steps an assistant may mark are exactly those the
// server lets anyone mark (manual or optional) minus those holding a
// credential.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_level_catalogue.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

Map<String, dynamic> _operation(String id) {
  final contract = jsonDecode(
    File('contracts/mcp/operations.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (contract['operations'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((o) => o['id'] == id);
}

List<Object?> _values(Map<String, dynamic> op, String field) =>
    ((op['input'] as Map)[field] as Map)['values'] as List;

void main() {
  test(
    'the latest setup_level_catalogue() carries the generated statement',
    () {
      final latest = sqlFiles('supabase/migrations')
          .lastWhere(
            (f) => f.readAsStringSync().contains(
              'function public.setup_level_catalogue(',
            ),
          )
          .readAsStringSync();
      expect(
        latest,
        contains(setupLevelCatalogueSql()),
        reason:
            'paste the output of dart run tool/build_setup_steps.dart '
            'unchanged into a new migration',
      );
    },
  );

  test('the level choices of the MCP contract are the levels table', () {
    for (final id in ['preview_setup_levels', 'apply_setup_levels']) {
      final op = _operation(id);
      for (final process in SetupProcess.values) {
        expect(_values(op, process.name), [
          for (final level in setupLevels[process]!) level.id,
        ], reason: '$id.${process.name}');
      }
      expect(_values(op, 'preset'), [
        for (final preset in SetupPreset.values) preset.name,
      ], reason: '$id.preset');
    }
  });

  test('an assistant may name only the steps anyone may mark, never one '
      'holding a credential', () {
    expect(_values(_operation('mark_setup_step'), 'step'), [
      for (final s in setupSteps)
        if ((s.evidence == 'manual' || !s.required) && !s.holdsSecret) s.id,
    ]);
    expect([
      for (final s in setupSteps)
        if (s.holdsSecret) s.id,
    ], containsAll(['online_payments', 'einvoicing']));
  });
}
