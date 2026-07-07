// SPDX-License-Identifier: MIT
//
// Two error-handling lints (from Sparkilo's CI):
//  - no empty `catch (_) {}` — errors must never be swallowed silently.
//  - every `catch (e)` must capture the stack trace: `catch (e, st)`.
//    A rethrow-only block may carry `// ignore: catch_no_st`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _silentCatch = RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}');
final _singleParamCatch = RegExp(r'catch\s*\(\s*(\w+)\s*\)');

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.contains('lib/l10n/'))
    .where((f) => !f.path.endsWith('.g.dart'))
    .where((f) => !f.path.endsWith('.freezed.dart'));

void main() {
  test('no silent catch (_) {} anywhere in lib/', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final content = file.readAsStringSync();
      if (_silentCatch.hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'Silent catches in: $violations');
  });

  test('every catch captures the stack trace (catch (e, st))', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _singleParamCatch.firstMatch(lines[i]);
        if (match == null) continue;
        final ignored = lines[i].contains('// ignore: catch_no_st') ||
            (i > 0 && lines[i - 1].contains('// ignore: catch_no_st'));
        if (!ignored) {
          violations.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'catch without stack trace in: $violations — '
          'use catch (e, st) and log st, or // ignore: catch_no_st '
          'for a rethrow-only block.',
    );
  });
}
