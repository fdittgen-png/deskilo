// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the XLSX writer is shared by the application's exports
// and the country add-ons' registers, so it stays a leaf: it imports core
// Dart and `archive` only, and depends on `archive` alone, so it cannot
// quietly grow dependencies.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_xlsx';

void main() {
  test('the writer imports core Dart, archive and its own files only', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final uri = importRe.firstMatch(line)?.group(1);
        if (uri == null) continue;
        final own = !uri.contains(':') && !uri.contains('..');
        if (!(uri.startsWith('dart:') ||
            uri.startsWith('package:archive/') ||
            own)) {
          bad.add('${f.path}:${i + 1}: $uri');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('the writer depends on archive alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, ['archive']);
  });
}
