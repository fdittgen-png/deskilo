// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 C3 - the package stays independent of the app: no Flutter, no
// package:deskilo, no path dependency, every source file licensed.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('the manifest has no Flutter, app or path dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final deps = pubspec.split('dev_dependencies:').first;
    expect(deps, isNot(contains('flutter')));
    expect(deps, isNot(contains('path:')));
    expect(deps, isNot(contains('deskilo:')));
    expect(pubspec, contains('publish_to: none'));
  });

  test('no source imports Flutter or the app', () {
    final bad = <String>[];
    for (final dir in ['lib', 'example']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final text = f.readAsStringSync();
        if (!text.startsWith('// SPDX-License-Identifier:')) {
          bad.add('${f.path}: no SPDX line');
        }
        for (final m in RegExp(
          r'''^(?:import|export) ['"]([^'"]+)''',
          multiLine: true,
        ).allMatches(text)) {
          final uri = m.group(1)!;
          if (uri.startsWith('package:flutter') ||
              uri.startsWith('package:deskilo/') ||
              uri.startsWith('dart:ui')) {
            bad.add('${f.path}: $uri');
          }
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('the schema versions are the documented ones', () {
    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('deskilo.task-recording'));
    expect(readme, contains('deskilo.task-guide'));
  });
}
