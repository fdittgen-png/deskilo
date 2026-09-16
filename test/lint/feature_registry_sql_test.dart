// SPDX-License-Identifier: 0BSD
//
// #1333 — the server's feature registry IS the Dart manifest.
//
// Server gates decide whether a feature is on through
// `public.feature_effective`, which reads `public.feature_registry()`:
// per key, the parent, the default and the tier. A second hand-typed copy
// of that map would drift the first time somebody added a feature — which
// is how five gates came to ignore their parents in the first place
// (#1332).
//
// So the SQL is GENERATED from `featureManifest`
// (`dart run tool/build_feature_registry_sql.dart`), and this test requires
// the latest migration defining the function to contain exactly that text.
// Adding, removing or re-parenting a feature, or changing its default or
// tier, fails here — naming the feature — until a migration carries the
// regenerated registry.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_registry_sql.dart';
import 'package:flutter_test/flutter_test.dart';

const _definition = 'create or replace function public.feature_registry()';

/// The latest migration that defines the registry, and its JSON literal.
({String file, Map<String, dynamic> registry})? _latestRegistry() {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files.reversed) {
    final sql = f.readAsStringSync();
    final at = sql.indexOf(_definition);
    if (at < 0) continue;
    final open = sql.indexOf("select '", at) + "select '".length;
    final close = sql.indexOf("'::jsonb", open);
    return (
      file: f.uri.pathSegments.last,
      registry: jsonDecode(sql.substring(open, close)) as Map<String, dynamic>,
    );
  }
  return null;
}

/// What differs between the generated registry and [stored], by feature.
List<String> registryDrift(Map<String, dynamic> stored) {
  final expected = jsonDecode(featureRegistryJson()) as Map<String, dynamic>;
  return [
    for (final key in expected.keys)
      if (!stored.containsKey(key))
        '$key: missing — expected ${jsonEncode(expected[key])}'
      else if (jsonEncode(stored[key]) != jsonEncode(expected[key]))
        '$key: stored ${jsonEncode(stored[key])}, expected '
            '${jsonEncode(expected[key])}',
    for (final key in stored.keys)
      if (!expected.containsKey(key)) '$key: in SQL, no longer in featureManifest',
  ];
}

void main() {
  test('the latest feature_registry() equals featureManifest', () {
    final latest = _latestRegistry();
    expect(latest, isNotNull, reason: 'no migration defines $_definition');
    final drift = registryDrift(latest!.registry);
    expect(drift, isEmpty,
        reason: '${latest.file} carries a registry that is not the Dart '
            'manifest:\n${drift.join('\n')}\n\n'
            'Write a new migration containing the output of\n'
            '  dart run tool/build_feature_registry_sql.dart');
  });

  test('the migration carries the generated statement verbatim', () {
    final latest = _latestRegistry()!;
    final sql = File('supabase/migrations/${latest.file}').readAsStringSync();
    expect(sql, contains(featureRegistrySql()),
        reason: 'paste the tool output unchanged — a hand-edited registry is '
            'the second copy this test exists to forbid');
  });

  group('the drift check can fail', () {
    Map<String, dynamic> generated() =>
        jsonDecode(featureRegistryJson()) as Map<String, dynamic>;

    test('a re-parented feature is named', () {
      final g = generated();
      (g['scheduledExpenses'] as Map)['parent'] = null;
      expect(registryDrift(g).single, startsWith('scheduledExpenses:'));
    });

    test('a missing and an extra feature are both named', () {
      final g = generated()
        ..remove('moneyTab')
        ..['ghost'] = {'parent': null, 'default': true, 'core': true};
      final drift = registryDrift(g);
      expect(drift, hasLength(2));
      expect(drift.first, startsWith('moneyTab: missing'));
      expect(drift.last, startsWith('ghost:'));
    });

    test('the generated registry has no drift against itself', () {
      expect(registryDrift(generated()), isEmpty);
    });
  });
}
