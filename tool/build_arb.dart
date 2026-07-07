// SPDX-License-Identifier: MIT
//
// Merges the per-feature ARB fragments in lib/l10n/_fragments/ into the
// aggregated lib/l10n/app_<locale>.arb files that flutter gen-l10n consumes.
//
// Fragment naming: <feature>_<locale>.arb (e.g. common_en.arb, plan_fr.arb).
// English (en) is the canonical locale: every key must exist in an _en
// fragment. The merge fails on duplicate keys across fragments of the same
// locale so two features can never silently shadow each other's strings.
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
    const encoder = JsonEncoder.withIndent('  ');
    out.writeAsStringSync('${encoder.convert(merged)}\n');
    stdout.writeln(
      'Wrote ${out.path} (${merged.keys.where((k) => !k.startsWith('@')).length} keys)',
    );
  }
}
