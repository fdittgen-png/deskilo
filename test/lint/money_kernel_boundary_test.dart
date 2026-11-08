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

/// The one file that only re-exports a package on purpose: the FOSS seam of
/// push (the app's build picks `deskilo_push` or `deskilo_push_foss` behind it).
const _exempt = {
  'lib/core/push/push_connector.dart':
      'the FOSS seam: the build swaps the package behind one app path',
};

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

  // Any package of the app (`deskilo_*`), a barrel or a sub-library, with or
  // without a `show`/`hide` list, and nothing else in the file.
  final onlyReExports = RegExp(
    r"^(?:export 'package:deskilo_\w+/[\w/]+\.dart'"
    r'(?: (?:show|hide) [\w, ]+)?;\s*)+$',
  );

  test('the matcher sees every shape of package re-export', () {
    for (final code in [
      "export 'package:deskilo_invoice_model/deskilo_invoice_model.dart';",
      "export 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart' hide X;",
      "export 'package:deskilo_push/deskilo_push.dart' show A, B;",
      "export 'package:deskilo_task_recording/step_values.dart';",
      "export 'package:deskilo_a/deskilo_a.dart'; export 'package:deskilo_b/deskilo_b.dart';",
    ]) {
      expect(onlyReExports.hasMatch(code), isTrue, reason: code);
    }
    for (final code in [
      "export 'local.dart';",
      "export 'package:flutter/material.dart';",
      "export 'package:deskilo_a/deskilo_a.dart'; void f() {}",
    ]) {
      expect(onlyReExports.hasMatch(code), isFalse, reason: code);
    }
  });

  test('no file in lib only re-exports a package (#3403)', () {
    final found = <String>{};
    for (final f in handWrittenDartFiles('lib')) {
      if (onlyReExports.hasMatch(codeOf(f.path))) found.add(f.path);
    }
    expect(
      found,
      _exempt.keys.toSet(),
      reason:
          'callers import the package; a new shim is a new dependency to '
          'justify here, with its reason',
    );
  });
}
