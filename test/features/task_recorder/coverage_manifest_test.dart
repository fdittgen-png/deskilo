// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1881 — the coverage manifest is complete and alive: every route the
// router classifies has exactly one row and every row a route; excluded
// rows name their protected category and planned rows their owner; and
// every registered action is called from a real seam outside the
// recorder (a dead identifier fails here, not in a field report).
import 'dart:io';

import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/task_recorder/domain/coverage_manifest.dart';
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/presentation/route_classification.dart';
import 'package:flutter_test/flutter_test.dart';

/// Actions no form calls, each for a stated reason.
const Map<String, String> _notCalledFromForms = {
  RecorderActions.recorderControl:
      'the recorder\'s own controls: registered so they can be refused',
};

void main() {
  test('one row per routed path, both ways', () {
    final routes = routeRules.map((r) => r.pattern).toList();
    final rows = routeCoverage.map((r) => r.route).toList();
    expect(rows.toSet().length, rows.length, reason: 'a route listed twice');
    expect(
      rows.toSet().difference(routes.toSet()),
      isEmpty,
      reason: 'a manifest row for a route the router does not have',
    );
    expect(
      routes.toSet().difference(rows.toSet()),
      isEmpty,
      reason: 'a routed path the manifest does not classify',
    );
  });

  test('every row says enough to be acted on', () {
    for (final row in routeCoverage) {
      switch (row.status) {
        case CoverageStatus.excluded:
          expect(row.category, isNotNull, reason: row.route);
        case CoverageStatus.planned:
          expect(
            row.owner,
            matches(RegExp(r'^#18(81 [ABC]|84)$')),
            reason: row.route,
          );
        case CoverageStatus.recorded:
        case CoverageStatus.recorder:
          expect(row.category ?? row.owner, isNull, reason: row.route);
      }
    }
  });

  test('the indicator reads the manifest', () {
    for (final row in routeCoverage) {
      final path = row.route.replaceAll(RegExp(r':\w+'), 'x1');
      final t = treatRoute(path);
      switch (row.status) {
        case CoverageStatus.excluded:
          expect((t as Protected).category, row.category, reason: row.route);
        case CoverageStatus.planned:
          expect(t, isA<Unrecorded>(), reason: row.route);
        case CoverageStatus.recorded:
        case CoverageStatus.recorder:
          expect(t, isA<Instrumented>(), reason: row.route);
      }
    }
  });

  test('every registered action is called from a seam', () {
    final registry = File(
      'lib/features/task_recorder/domain/action_registry.dart',
    ).readAsStringSync();
    final block = registry.substring(
      registry.indexOf('abstract final class RecorderActions'),
    );
    final names = {
      for (final m in RegExp(
        r"static const (\w+) = '([^']+)'",
      ).allMatches(block.substring(0, block.indexOf('}'))))
        m.group(2)!: m.group(1)!,
    };
    expect(
      names.keys.toSet(),
      recorderRegistry.actions.map((a) => a.id).toSet(),
      reason: 'every action has a constant, and only actions do',
    );
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              // The forms, and the adapters they call (an adapter maps a
              // form's own choice to the action it is).
              (!f.path.contains('/features/task_recorder/') ||
                  f.path.contains('/features/task_recorder/application/')),
        )
        .map((f) => f.readAsStringSync())
        .join('\n');
    final dead = [
      for (final e in names.entries)
        if (!_notCalledFromForms.containsKey(e.key) &&
            !sources.contains('RecorderActions.${e.value}'))
          e.key,
    ];
    expect(dead, isEmpty, reason: 'registered but called from no form');
  });
}
