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
// Usage:
//   dart run tool/build_arb.dart
//   flutter gen-l10n   (always run afterwards)

import 'dart:convert';
import 'dart:io';

const supportedLocales = ['en', 'fr', 'de', 'es', 'it'];
const fragmentsDir = 'lib/l10n/_fragments';
const outputDir = 'lib/l10n';

void main() {
  final dir = Directory(fragmentsDir);
  if (!dir.existsSync()) {
    stderr.writeln('No $fragmentsDir directory found.');
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

    final out = File('$outputDir/app_$locale.arb');
    out.writeAsStringSync(encodeArb(merged));
    stdout.writeln(
      'Wrote ${out.path} (${merged.keys.where((k) => !k.startsWith('@')).length} keys)',
    );
  }
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
