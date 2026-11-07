// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3401 (of #3328) -- the tax reference package is the data model only: it
// imports core Dart, the money kernel and itself, depends on the kernel alone,
// and names no installed snapshot -- `ActiveTaxReference` is the application's
// global, handed to a format as a set, never reached for.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_tax_reference';

void main() {
  test('the package imports core Dart, the kernel and its own files only', () {
    final bad = <String>[];
    final importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');
    final sources = filesWithExtension('$_root/lib', '.dart', recursive: true);
    expect(sources, isNotEmpty);
    for (final f in sources) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        final m = importRe.firstMatch(line);
        if (m == null) continue;
        final uri = m.group(1)!;
        final own = !uri.contains(':') && !uri.contains('..');
        final ok =
            uri.startsWith('dart:') ||
            uri.startsWith('package:deskilo_money_kernel/') ||
            uri.startsWith('package:deskilo_tax_reference/') ||
            own;
        if (!ok) bad.add('${f.path}:${i + 1}: $uri');
      }
    }
    expect(bad, isEmpty, reason: 'the data model reaches nothing else:\n${bad.join('\n')}');
  });

  test('the package depends on the money kernel alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, ['deskilo_money_kernel']);
  });

  test('no source of the package names the installed snapshot', () {
    final named = [
      for (final f in filesWithExtension('$_root/lib', '.dart', recursive: true))
        if (f.readAsStringSync().contains('ActiveTaxReference')) f.path,
    ];
    expect(named, isEmpty, reason: 'the global stays in the application');
  });
}
