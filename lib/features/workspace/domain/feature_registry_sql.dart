// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:meta/meta.dart';
import 'workspace_feature.dart';

/// #1333 — the feature registry as the database reads it.
///
/// The client decides whether a feature is on in two steps: a stored JSON
/// boolean over the registry default, then every `requires` parent on
/// (`resolveEnabledFeatures` → `effectiveFeatures`). Server gates used to
/// read the one flag in front of them, each with its own idea of the
/// default, so a child stored `true` under a parent switched off passed a
/// gate the app showed as off (#1332).
///
/// The SQL `public.feature_registry()` carries, per key, the parent, the
/// default and whether the feature is core — generated HERE from
/// [featureManifest], never typed by hand. `feature_registry_sql_test`
/// requires the rows the migrations accumulate to equal this, so adding or
/// re-parenting a feature without a migration that carries its rows fails the
/// build and names the feature.
@visibleForTesting
String featureRegistryJson() {
  final lines = <String>[];
  for (final entry in featureManifest.values) {
    final parent = entry.requires == null ? 'null' : '"${entry.requires!.dbKey}"';
    final countries = entry.availableIn == null
        ? ''
        : ', "countries": [${([...entry.availableIn!]..sort()).map((c) => '"$c"').join(', ')}]';
    lines.add('    "${entry.feature.dbKey}": {"parent": $parent, '
        '"default": ${entry.defaultOn}, '
        '"core": ${entry.tier == FeatureTier.core}$countries}');
  }
  return '{\n${lines.join(',\n')}\n  }';
}

/// #4396 -- the registry is ROWS (`public.feature_registry_entries`, 0949), read by `feature_registry()`; the function
/// is never restated to change content. A migration that adds, re-parents or removes a feature carries the rows of
/// that one change between these markers, written by `dart run tool/build_feature_registry_sql.dart`; the lint reads
/// every such block, in migration order, and requires the rows they accumulate to be the manifest's.
@visibleForTesting
const featureRegistryRowsBegin = '-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)';
@visibleForTesting
const featureRegistryRowsEnd = '-- END FEATURE REGISTRY ROWS';

/// One feature as the registry answers it: `{parent, default, core[, countries]}`.
typedef FeatureRegistryEntry = Map<String, Object?>;

/// The manifest as registry entries, by feature key, typed (the shape [featureRegistryJson] prints).
Map<String, FeatureRegistryEntry> _featureRegistryEntries() => {
  for (final entry in featureManifest.values)
    entry.feature.dbKey: {
      'parent': entry.requires?.dbKey,
      'default': entry.defaultOn,
      'core': entry.tier == FeatureTier.core,
      if (entry.availableIn != null) 'countries': [...entry.availableIn!]..sort(),
    },
};

final _rowPattern = RegExp(r"\('(\w+)', (null|'\w+'), (true|false), (true|false), (null|array\[[^\]]*\])\)");
final _deletePattern = RegExp(r"delete from public\.feature_registry_entries where feature_key = '(\w+)';");
final _countryPattern = RegExp(r"'([^']+)'");

/// The entry one row of a block writes.
FeatureRegistryEntry _entryOfRow(Match row) {
  final parent = row.group(2)!;
  final countries = row.group(5)!;
  return {
    'parent': parent == 'null' ? null : parent.substring(1, parent.length - 1),
    'default': row.group(3) == 'true',
    'core': row.group(4) == 'true',
    if (countries != 'null') 'countries': [for (final c in _countryPattern.allMatches(countries)) c.group(1)!],
  };
}

/// Applies the rows and the deletions of one [block] to [registry], in the order they are written.
void _applyBlock(Map<String, FeatureRegistryEntry> registry, String block) {
  final steps = <int, void Function()>{
    for (final m in _rowPattern.allMatches(block)) m.start: () => registry[m.group(1)!] = _entryOfRow(m),
    for (final m in _deletePattern.allMatches(block)) m.start: () => registry.remove(m.group(1)),
  };
  for (final at in steps.keys.toList()..sort()) {
    steps[at]!();
  }
}

/// The marked blocks of a migration [source].
Iterable<String> _blocksOf(String source) sync* {
  var from = 0;
  while (true) {
    final begin = source.indexOf(featureRegistryRowsBegin, from);
    if (begin < 0) return;
    final end = source.indexOf(featureRegistryRowsEnd, begin);
    if (end < 0) throw const FormatException('a feature registry block is not closed');
    yield source.substring(begin, end);
    from = end;
  }
}

/// The registry the migrations [sources] (in migration order) accumulate: the rows of every marked block, later
/// rows replacing earlier ones, a deleted feature gone. In the shape of [featureRegistryJson].
Map<String, FeatureRegistryEntry> accumulatedFeatureRegistry(Iterable<String> sources) {
  final registry = <String, FeatureRegistryEntry>{};
  for (final source in sources) {
    _blocksOf(source).forEach((block) => _applyBlock(registry, block));
  }
  return registry;
}

/// Every feature key a migration [source] writes a row for, whether or not a later block removes it.
@visibleForTesting
Set<String> featureRegistryRowKeys(String source) => {
  for (final block in _blocksOf(source))
    for (final m in _rowPattern.allMatches(block)) m.group(1)!,
};

/// The block a migration carries to bring [stored] (what the migrations accumulate) to [featureRegistryEntries]: only
/// the rows that are new or changed, and a deletion for each feature no longer in the manifest. Null when there is
/// nothing to carry.
String? featureRegistryRowsSql(Map<String, FeatureRegistryEntry> stored) {
  final expected = _featureRegistryEntries();
  final rows = <String>[];
  for (final MapEntry(:key, :value) in expected.entries) {
    if (stored.containsKey(key) && jsonEncode(stored[key]) == jsonEncode(value)) continue;
    final parent = value['parent'] == null ? 'null' : "'${value['parent']}'";
    final countries = value['countries'] == null ? 'null' : "array[${(value['countries']! as List<String>).map((c) => "'$c'").join(', ')}]";
    rows.add("('$key', $parent, ${value['default']}, ${value['core']}, $countries)");
  }
  final gone = [for (final key in stored.keys) if (!expected.containsKey(key)) key];
  if (rows.isEmpty && gone.isEmpty) return null;
  return [
    featureRegistryRowsBegin,
    if (rows.isNotEmpty) ...[
      'insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values',
      rows.join(',\n'),
      'on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, '
          'core = excluded.core, countries = excluded.countries;',
    ],
    for (final key in gone) "delete from public.feature_registry_entries where feature_key = '$key';",
    featureRegistryRowsEnd,
  ].join('\n');
}
