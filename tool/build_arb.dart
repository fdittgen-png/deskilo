// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Merges the per-feature ARB fragments in lib/l10n/_fragments/ into the
// aggregated lib/l10n/app_<locale>.arb files that flutter gen-l10n consumes.
//
// Fragment naming: <feature>_<locale>.arb (e.g. common_en.arb, plan_fr.arb).
// English (en) is the canonical locale: every key must exist in an _en
// fragment. The merge fails on duplicate keys across fragments of the same
// locale so two features can never silently shadow each other's strings.
//
// The aggregate is sorted by key (a key's `@key` metadata right after it),
// never in fragment order: two pull requests that each add strings to the
// same feature then insert at different places of the aggregate instead of
// both appending at the end of that feature's block, so git merges them
// without a conflict and the merged file is still exactly what this tool
// writes (test/tool/generated_merge_test.dart).
//
// #3486 — every English key carries `@key.description`: the translator's
// only context otherwise is the key's name. The keys recorded without one in
// tool/arb_undescribed_keys.txt are allowed until they get one; a new key
// without a description, or a listed key that now has one, fails the build.
//
// Usage:
//   dart run tool/build_arb.dart [--fragments <dir>] [--out <dir>]
//                                [--undescribed <file>]
//   flutter gen-l10n   (always run afterwards)

import 'dart:convert';
import 'dart:io';

const supportedLocales = ['en', 'fr', 'de', 'es', 'it'];
const fragmentsDir = 'lib/l10n/_fragments';
const outputDir = 'lib/l10n';
const undescribedList = 'tool/arb_undescribed_keys.txt';

void main(List<String> args) {
  String option(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final fragments = option('fragments', fragmentsDir);
  final output = option('out', outputDir);
  final undescribedFile = option('undescribed', undescribedList);
  final dir = Directory(fragments);
  if (!dir.existsSync()) {
    stderr.writeln('No $fragments directory found.');
    exitCode = 1;
    return;
  }

  final fragmentFiles = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final locale in supportedLocales) {
    final merged = <String, dynamic>{'@@locale': locale};
    final keyOrigin = <String, String>{};

    for (final file in fragmentFiles) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('_$locale.arb')) continue;

      final content = jsonDecode(file.readAsStringSync());
      if (content is! Map<String, dynamic>) {
        stderr.writeln('$name: not a JSON object.');
        exitCode = 1;
        return;
      }
      for (final entry in content.entries) {
        if (entry.key == '@@locale') continue;
        final bareKey = entry.key.startsWith('@')
            ? entry.key.substring(1)
            : entry.key;
        final origin = keyOrigin[bareKey];
        if (origin != null && origin != name && !entry.key.startsWith('@')) {
          stderr.writeln(
            'Duplicate key "$bareKey" in $name (already defined in $origin).',
          );
          exitCode = 1;
          return;
        }
        keyOrigin[bareKey] = origin ?? name;
        merged[entry.key] = entry.value;
      }
    }

    if (locale == 'en' && !_descriptionsHold(merged, undescribedFile)) {
      exitCode = 1;
      return;
    }

    final out = File('$output/app_$locale.arb')
      ..writeAsStringSync(encodeArb(merged));
    stdout.writeln(
      'Wrote ${out.path} (${merged.keys.where((k) => !k.startsWith('@')).length} keys)',
    );
  }
}

/// The English keys without a non-empty `@key.description`.
Set<String> undescribedKeys(Map<String, dynamic> english) => {
  for (final k in english.keys)
    if (!k.startsWith('@') && !_described(english['@$k'])) k,
};

bool _described(Object? meta) =>
    meta is Map &&
    meta['description'] is String &&
    (meta['description'] as String).trim().isNotEmpty;

/// Whether the English keys keep #3486's rule against [listFile]; the
/// reasons it does not are written to stderr.
bool _descriptionsHold(Map<String, dynamic> english, String listFile) {
  final file = File(listFile);
  final allowed = file.existsSync()
      ? {
          for (final line in file.readAsLinesSync())
            if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
        }
      : <String>{};
  final missing = undescribedKeys(english);
  final added = missing.difference(allowed).toList()..sort();
  final described = allowed.difference(missing).toList()..sort();
  for (final k in added) {
    stderr.writeln('"$k" has no @$k.description: say what a translator needs '
        'to know (where it shows, what the placeholders are).');
  }
  for (final k in described) {
    stderr.writeln('"$k" is described now (or gone): remove it from $listFile.');
  }
  return added.isEmpty && described.isEmpty;
}

/// The aggregate's text: `@@locale` first, then every key in code-unit
/// order with its `@key` metadata immediately after it. The order is a
/// function of the keys alone, so it does not depend on which fragment or
/// which pull request contributed a key.
String encodeArb(Map<String, dynamic> merged) {
  String bare(String k) => k.startsWith('@') ? k.substring(1) : k;
  final keys = merged.keys.where((k) => !k.startsWith('@@')).toList()
    ..sort((a, b) {
      final byKey = bare(a).compareTo(bare(b));
      if (byKey != 0) return byKey;
      return a.startsWith('@') ? 1 : -1;
    });
  final sorted = <String, dynamic>{
    for (final k in merged.keys.where((k) => k.startsWith('@@'))) k: merged[k],
    for (final k in keys) k: merged[k],
  };
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(sorted)}\n';
}
