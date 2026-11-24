// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1333, #4396 -- the server's feature registry IS the Dart manifest.
//
// Server gates decide whether a feature is on through `public.feature_effective`, which reads `public.feature_registry()`:
// per key, the parent, the default and the tier. A second hand-typed copy of that map would drift the first time somebody
// added a feature -- which is how five gates came to ignore their parents in the first place (#1332).
//
// Since 0949 the registry is ROWS (`feature_registry_entries`), read by a `feature_registry()` that is never restated.
// A migration that adds, re-parents or removes a feature carries the rows of that one change between the markers
// `dart run tool/build_feature_registry_sql.dart` writes; this test accumulates every block in migration order and
// requires the manifest. Adding, removing or re-parenting a feature, or changing its default or tier, fails here --
// naming the feature -- until a migration carries its rows.
import 'dart:convert';

import 'package:deskilo/features/workspace/domain/feature_registry_sql.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The migration that makes the registry rows: from it on, nothing restates the function.
const _rowsFrom = '0949';

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

Map<String, String> _migrations() => {
  for (final f in sqlFiles('supabase/migrations')) f.uri.pathSegments.last.substring(0, 4): f.readAsStringSync(),
};

void main() {
  test('the rows the migrations accumulate equal featureManifest', () {
    final sources = _migrations();
    final stored = accumulatedFeatureRegistry([for (final k in sources.keys.toList()..sort()) sources[k]!]);
    final drift = registryDrift(stored);
    expect(drift, isEmpty,
        reason: 'the migrations carry a registry that is not the Dart manifest:\n${drift.join('\n')}\n\n'
            'Put the output of\n  dart run tool/build_feature_registry_sql.dart\ninto the migration that adds the feature.');
  });

  test('the generator writes exactly what is missing, and nothing when nothing is', () {
    final sources = _migrations();
    final stored = accumulatedFeatureRegistry([for (final k in sources.keys.toList()..sort()) sources[k]!]);
    expect(featureRegistryRowsSql(stored), isNull);
    final fewer = {...stored}
      ..remove('moneyTab')
      ..['ghost'] = {'parent': null, 'default': true, 'core': true};
    final block = featureRegistryRowsSql(fewer)!;
    expect(block, contains("('moneyTab', null, true, true, null)"));
    expect("('".allMatches(block), hasLength(1), reason: 'only the missing row');
    expect(block, contains("delete from public.feature_registry_entries where feature_key = 'ghost';"));
    // the block it writes is read back as the manifest
    expect(registryDrift(accumulatedFeatureRegistry([...sources.values, block])), isEmpty);
  });

  test('no migration after 0949 restates feature_registry(): a feature is a row', () {
    final restated = [
      for (final MapEntry(:key, :value) in _migrations().entries)
        if (key.compareTo(_rowsFrom) > 0 && RegExp(r'create\s+or\s+replace\s+function\s+public\.feature_registry\s*\(', caseSensitive: false).hasMatch(value)) key,
    ];
    expect(restated, isEmpty, reason: 'insert the row between the feature registry markers instead (0949)');
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

  group('the block reader', () {
    const open = featureRegistryRowsBegin;
    const close = featureRegistryRowsEnd;

    test('later rows replace earlier ones, a deletion removes, a country list is read', () {
      final stored = accumulatedFeatureRegistry([
        '$open\ninsert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values\n'
            "('a', null, true, true, null),\n('b', 'a', false, false, array['GB', '@eu'])\non conflict (feature_key) do update set parent = excluded.parent;\n$close",
        "-- another migration\n$open\ninsert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values\n('a', null, false, true, null)\non conflict (feature_key) do update set parent = excluded.parent;\n"
            "delete from public.feature_registry_entries where feature_key = 'b';\n$close",
      ]);
      expect(stored, {'a': {'parent': null, 'default': false, 'core': true}});
      final countries = accumulatedFeatureRegistry([
        "$open\ninsert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values\n('b', 'a', false, false, array['GB', '@eu'])\n$close",
      ]);
      expect(countries['b'], {'parent': 'a', 'default': false, 'core': false, 'countries': ['GB', '@eu']});
    });

    test('a block that is not closed is refused, and text outside the markers is not read', () {
      expect(() => accumulatedFeatureRegistry(['$open\n']), throwsFormatException);
      expect(accumulatedFeatureRegistry(["('x', null, true, true, null)"]), isEmpty);
    });
  });
}
