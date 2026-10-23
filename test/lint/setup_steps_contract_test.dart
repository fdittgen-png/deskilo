// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2867 (ADR 0047 §1) — the setup step catalogue has one canonical home,
// `setup_steps.dart`. Its two copies — the shared contract
// `contracts/setup/steps.json` and the server's `setup_step_catalogue()` —
// are generated from it, and the catalogue itself holds together: unique
// ids, dependencies that exist and never loop, and a server detector for
// every evidence it names.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The latest migration that defines [function], as text.
String _latestDefining(String function) => sqlFiles('supabase/migrations')
    .lastWhere(
      (f) => f.readAsStringSync().contains('function public.$function('),
    )
    .readAsStringSync();

void main() {
  test('contracts/setup/steps.json is the generated catalogue', () {
    expect(
      File('contracts/setup/steps.json').readAsStringSync(),
      setupStepsJson(),
      reason: 'run: dart run tool/build_setup_steps.dart',
    );
  });

  test('the latest setup_step_catalogue() carries the generated statement', () {
    expect(
      _latestDefining('setup_step_catalogue'),
      contains(setupStepCatalogueSql()),
      reason:
          'paste the output of dart run tool/build_setup_steps.dart '
          'unchanged into a new migration',
    );
  });

  test('ids are unique and every dependency is a step of the catalogue', () {
    final ids = [for (final s in setupSteps) s.id];
    expect(ids.toSet().length, ids.length, reason: 'a step id twice');
    final unknown = [
      for (final s in setupSteps)
        for (final d in s.dependsOn)
          if (!ids.contains(d)) '${s.id} -> $d',
    ];
    expect(unknown, isEmpty);
  });

  test('the dependencies never loop', () {
    final byId = {for (final s in setupSteps) s.id: s};
    String? loopFrom(String id, List<String> path) {
      if (path.contains(id)) return [...path, id].join(' -> ');
      for (final d in byId[id]!.dependsOn) {
        final loop = loopFrom(d, [...path, id]);
        if (loop != null) return loop;
      }
      return null;
    }

    final loops = [for (final s in setupSteps) ?loopFrom(s.id, const [])];
    expect(loops, isEmpty);
  });

  test('every evidence has its detector in workspace_setup_status', () {
    final status = _latestDefining('workspace_setup_status');
    final missing = [
      for (final s in setupSteps)
        if (s.evidence != 'manual' && !status.contains("'${s.evidence}',"))
          s.evidence,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'name the detector in v_evidence, or make the step manual',
    );
  });

  test('a step never depends on a later milestone', () {
    final byId = {for (final s in setupSteps) s.id: s};
    final backwards = [
      for (final s in setupSteps)
        for (final d in s.dependsOn)
          if (byId[d]!.milestone.index > s.milestone.index) '${s.id} -> $d',
    ];
    expect(
      backwards,
      isEmpty,
      reason: 'a milestone would wait for a step of a later one',
    );
  });
}
