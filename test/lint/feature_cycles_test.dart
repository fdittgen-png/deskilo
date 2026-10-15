// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the ratchet on the WHOLE feature graph, not on pairs.
//
// A mutual pair is the shortest cycle; `money -> members -> workspace ->
// money` has no reciprocal pair and is a cycle all the same. This holds
// (a) the strongly connected components, (b) the mutual pairs, (c) the
// imports against the declared direction (feature_layers.yaml) and (d) the
// imports from core into a feature. Every baseline below may only fall:
// a number that dropped asks to be lowered, a new entry is a failure.
//
// "Acyclic" is said only when the components list is empty.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/layering/analysis.dart';

/// The one component that exists today. Features may leave it, none may join.
const Set<String> _component = {
  'calendar',
  'directory',
  'events',
  'mcp',
  'members',
  'money',
  'plan',
  'profile',
  'reservations',
  'task_recorder',
  'workspace',
};

/// Mutual pairs today (24 at the time of the issue plus the count of the
/// generated map). A pair leaves this set when its last reverse import goes.
const Set<String> _mutualPairs = {
  'calendar <-> money',
  'calendar <-> reservations',
  'calendar <-> task_recorder',
  'directory <-> workspace',
  'events <-> money',
  'events <-> plan',
  'events <-> reservations',
  'events <-> task_recorder',
  'events <-> workspace',
  'members <-> money',
  'members <-> plan',
  'members <-> profile',
  'members <-> reservations',
  'members <-> workspace',
  'money <-> plan',
  'money <-> profile',
  'money <-> reservations',
  'money <-> workspace',
  'plan <-> reservations',
  'plan <-> workspace',
  'profile <-> reservations',
  'profile <-> workspace',
  'reservations <-> task_recorder',
  'reservations <-> workspace',
  'task_recorder <-> workspace',
};

/// Imports against the declared direction (feature_layers.yaml).
const Map<String, int> _upwardImports = {
  'help -> workspace': 1,
  'profile -> calendar': 2,
  'profile -> directory': 1,
  'profile -> mcp': 1,
  'profile -> members': 1,
  'profile -> money': 1,
  'profile -> reservations': 5,
  'profile -> workspace': 43,
  'workspace -> directory': 21,
  'workspace -> events': 15,
  'workspace -> members': 4,
  'workspace -> money': 45,
  'workspace -> plan': 26,
  'workspace -> reservations': 17,
  'workspace -> task_recorder': 9,
};

/// Imports from `lib/core` into a feature, per core area (the real
/// inversions; `core/demo` mirrors the features by design).
const Map<String, int> _coreToFeature = {
  'core/i18n': 4,
  'core/privacy': 3,
  'core/push': 2,
  'core/realtime': 10,
};

List<List<String>> _declaredLayers() {
  final y = loadYaml(File('test/lint/feature_layers.yaml').readAsStringSync())
      as YamlMap;
  return [
    for (final l in y['layers'] as YamlList)
      [for (final f in l as YamlList) f as String],
  ];
}

/// Failures of [now] against [baseline]: a new key or a higher number, and
/// a lower number or a vanished key (the baseline must follow it down).
List<String> _ratchet(Map<String, int> now, Map<String, int> baseline) => [
  for (final e in now.entries)
    if (!baseline.containsKey(e.key))
      'NEW ${e.key} (${e.value})'
    else if (e.value > baseline[e.key]!)
      'RISEN ${e.key}: ${baseline[e.key]} -> ${e.value}',
  for (final e in baseline.entries)
    if ((now[e.key] ?? 0) < e.value)
      'LOWER the baseline: ${e.key}: ${e.value} -> ${now[e.key] ?? 0}',
];

void main() {
  final features = handWrittenDartFiles('lib/features').toList();
  final counts = crossFeatureImports(features);

  group('the tree', () {
    test('no new strongly connected component, and none grows', () {
      final components = stronglyConnected(counts.keys);
      final members = {for (final c in components) ...c};
      expect(members.difference(_component), isEmpty,
          reason: 'a feature joined a dependency cycle');
      expect(components.length, lessThanOrEqualTo(1),
          reason: 'a second component appeared: $components');
      expect(_component.difference(members), isEmpty,
          reason: 'left the component: delete them from _component');
    });

    test('mutual pairs only fall', () {
      final now = reciprocalPairs(counts);
      expect(now.difference(_mutualPairs), isEmpty,
          reason: 'a new pair of features imports each other');
      expect(_mutualPairs.difference(now), isEmpty,
          reason: 'a pair was untangled: delete it from _mutualPairs');
    });

    test('imports against the declared direction only fall', () {
      expect(_ratchet(layerViolations(counts, _declaredLayers()), _upwardImports),
          isEmpty);
    });

    test('core imports of a feature only fall', () {
      final now =
          coreToFeatureImports(handWrittenDartFiles('lib/core').toList());
      expect(_ratchet(now, _coreToFeature), isEmpty);
    });

    test('every feature belongs to a declared layer', () {
      final declared = {for (final l in _declaredLayers()) ...l};
      final known = {
        for (final f in features)
          if (featureOf(f.path) != null) featureOf(f.path)!,
      };
      expect(known.difference(declared), isEmpty);
    });
  });

  group('the measure, on synthetic modules', () {
    test('a 3-cycle without a reciprocal pair is a component', () {
      const edges = ['a -> b', 'b -> c', 'c -> a', 'c -> d'];
      expect(reciprocalPairs({for (final e in edges) e: 1}), isEmpty);
      expect(stronglyConnected(edges), [
        ['a', 'b', 'c'],
      ]);
      expect(shortestCycle(['a', 'b', 'c'], edges), 'a -> b -> c -> a');
    });

    test('an acyclic graph has no component', () {
      expect(stronglyConnected(['a -> b', 'b -> c', 'a -> c']), isEmpty);
    });

    test('an import against the declared direction fails; fixing it passes',
        () {
      const layers = [
        ['low'],
        ['high'],
      ];
      expect(layerViolations({'low -> high': 3, 'high -> low': 9}, layers),
          {'low -> high': 3});
      expect(layerViolations({'high -> low': 9}, layers), isEmpty);
      expect(_ratchet({'low -> high': 3}, {}), ['NEW low -> high (3)']);
      expect(_ratchet({}, {'low -> high': 3}),
          ['LOWER the baseline: low -> high: 3 -> 0']);
    });
  });
}
