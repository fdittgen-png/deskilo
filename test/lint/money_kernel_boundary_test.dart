// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3376 (of #3328) -- the money kernel is the bottom of the accounting model:
// it imports nothing of the application, Flutter or any package, and the old
// paths of what moved into it are shims that only re-export, listed here until
// the sweep PR deletes them (the list only shrinks).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _root = 'packages/deskilo_money_kernel';

/// The old paths, kept as re-exports until every importer is rewritten.
const _shims = <String>{};

void main() {
  test('the kernel imports core Dart, crypto and its own files only', () {
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
            uri.startsWith('package:crypto/') ||
            uri.startsWith('package:meta/') ||
            own;
        if (!ok) {
          bad.add('${f.path}:${i + 1}: $uri');
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          'the kernel may not reach the application, Flutter or a package '
          '(not even a global like the active tax reference):\n${bad.join('\n')}',
    );
  });

  test('the kernel depends on crypto and meta alone', () {
    final text = File('$_root/pubspec.yaml').readAsStringSync();
    final deps = RegExp(r'^dependencies:\n((?:  .+\n?)+)', multiLine: true)
        .firstMatch(text)!
        .group(1)!
        .split('\n')
        .where((l) => RegExp(r'^  [a-z_]+:').hasMatch(l))
        .map((l) => l.trim().split(':').first)
        .toList();
    expect(deps, ['crypto', 'meta']);
  });

  /// The code of [path] with comments and blank lines dropped, on one line.
  String codeOf(String path) =>
      File(path)
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('//'))
          .map((l) => l.trim())
          .join(' ');

  const package =
      r'(money_kernel|accounting_interchange|tax_reference|vat_declaration)';

  test('a shim only re-exports a package (a hide list names the wrapped functions)', () {
    final exportRe = RegExp(
      "^export 'package:deskilo_$package/deskilo_\\1\\.dart'"
      r'(?: hide [\w, ]+)?;$',
    );
    for (final path in _shims) {
      final code = codeOf(path);
      expect(
        exportRe.hasMatch(code),
        isTrue,
        reason: '$path holds more than a re-export: $code',
      );
    }
  });

  test('no other file in lib only re-exports a package', () {
    final found = <String>{};
    final exportRe = RegExp(
      "^export 'package:deskilo_$package/deskilo_\\1\\.dart'"
      r'(?: hide [\w, ]+)?;$',
    );
    for (final f in handWrittenDartFiles('lib')) {
      if (exportRe.hasMatch(codeOf(f.path))) found.add(f.path);
    }
    expect(
      found,
      _shims,
      reason:
          'a new shim is a new dependency to justify; the list only shrinks',
    );
  });
}
