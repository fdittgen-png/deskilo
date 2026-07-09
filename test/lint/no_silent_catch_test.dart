// SPDX-License-Identifier: MIT
//
// Error-handling lints (from Sparkilo's CI, extended for #145):
//  - no empty `catch (_) {}` — errors must never be swallowed silently.
//  - every `catch (e)` must capture the stack trace: `catch (e, st)`.
//    A rethrow-only block may carry `// ignore: catch_no_st`.
//  - every catch block must trace (#145): its body has to contain
//    `TraceLogger`, a provider-injected `logger.error(`/`logger.warn(`,
//    `rethrow`, `throw `, or the marker `// trace-exempt: <reason>`.
//    lib/core/trace/ is excluded — the logger's own IO guards must never
//    call the logger recursively.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _silentCatch = RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}');
final _singleParamCatch = RegExp(r'catch\s*\(\s*(\w+)\s*\)');
final _catchKeyword = RegExp(r'\bcatch\s*\(');
// `logger.`/`trace.` cover the injected/aliased TraceLogger call sites
// (developer_screen's provider-read logger, main.dart's bootstrap alias).
final _tracedBody = RegExp(
  r'TraceLogger|\b(?:logger|trace)\.(?:error|warn|log)\(|\brethrow\b|\bthrow |// trace-exempt:',
);

/// The `{...}` block body following the catch clause that starts at
/// [catchStart], found by brace matching. Returns null when no block
/// opens on that clause (defensive — should not happen in valid Dart).
String? _catchBlockBody(String content, int catchStart) {
  final open = content.indexOf('{', catchStart);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < content.length; i++) {
    final char = content[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return content.substring(open + 1, i);
    }
  }
  return null;
}

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

  test('every catch block traces through TraceLogger (#145)', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      // The trace logger's own IO guards must stay logger-free — calling
      // the logger from inside its failure paths would recurse.
      if (file.path.contains('lib/core/trace/')) continue;
      final content = file.readAsStringSync();
      for (final match in _catchKeyword.allMatches(content)) {
        final body = _catchBlockBody(content, match.start);
        if (body == null || !_tracedBody.hasMatch(body)) {
          final line =
              '\n'.allMatches(content.substring(0, match.start)).length + 1;
          violations.add('${file.path}:$line');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'silent catch block(s) in: $violations — every catch must '
          'call TraceLogger.instance.error/.warn (or an injected '
          'logger.error/.warn), rethrow/throw, or carry '
          '// trace-exempt: <reason>.',
    );
  });
}
