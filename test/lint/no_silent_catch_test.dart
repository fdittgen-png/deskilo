// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Error-handling lints (from Sparkilo's CI, extended for #145):
//  - no empty `catch (_) {}` — errors must never be swallowed silently.
//  - every `catch (e)` must capture the stack trace: `catch (e, st)`.
//    There is no exemption: a block that only translates carries the
//    stack on with `Error.throwWithStackTrace(typed, st)`.
//  - every catch block must trace (#145): its body has to contain
//    `TraceLogger`, an `ActTrace.` call, a named `traceX(...)` trace
//    point, a provider-injected `logger.error(`/`logger.warn(`,
//    `rethrow`, `throw `, `Error.throwWithStackTrace(` (the same throw,
//    stack kept), or the marker `// trace-exempt: <reason>`.
//    lib/core/trace/ is excluded — the logger's own IO guards must never
//    call the logger recursively.
//  - #4410 — a clause `} on T {` has no `catch` keyword and escaped the
//    rule above. Those that neither trace nor throw are counted per area
//    (lib and the packages' libraries), and the count only falls; so is
//    every `// trace-exempt:` marker, which also has to give its reason.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _silentCatch = RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}');
final _singleParamCatch = RegExp(r'catch\s*\(\s*(\w+)\s*\)');
final _catchKeyword = RegExp(r'\bcatch\s*\(');
// `logger.`/`trace.` cover the injected/aliased TraceLogger call sites
// (developer_screen's provider-read logger, main.dart's bootstrap alias).
//
// #1030 — `ActTrace` and the named `traceX(...)` helpers in the
// `*_trace_points.dart` files also satisfy this: both write through
// `TraceLogger`, and both exist BECAUSE an inline call could not carry
// the context (the seat, the window, the server's own answer) that made
// a field report answerable. Requiring the literal word `TraceLogger`
// in the catch pushed those calls back inline, which is the thing the
// helpers were extracted to stop.
final _tracedBody = RegExp(
  r'TraceLogger'
  r'|\bActTrace\.'
  r'|\btrace[A-Z]\w*\('
  r'|\b(?:logger|trace)\.(?:error|warn|log)\('
  r'|\brethrow\b|\bthrow |\bError\.throwWithStackTrace\(|// trace-exempt:',
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


/// #4410 — a clause that catches without the `catch` keyword:
/// `} on FormatException {`. `on T catch (e, st) {` is the rule above's.
final _onClause = RegExp(r'\}\s*on\s+[\w.<>?, ]+\{');

/// A `// trace-exempt:` marker, and one that says nothing after the colon.
final _exemptMarker = RegExp(r'//\s*trace-exempt:');
final _exemptWithoutReason = RegExp(r'//\s*trace-exempt:\s*$', multiLine: true);

/// The area a file is counted under: a feature, a top-level folder of lib,
/// or a package.
String _areaOf(String path) {
  final p = path.replaceAll('\\', '/');
  final pkg = RegExp(r'packages/([\w]+)/lib/').firstMatch(p);
  if (pkg != null) return 'packages/${pkg.group(1)}';
  final feature = RegExp(r'lib/features/([\w]+)/').firstMatch(p);
  if (feature != null) return 'features/${feature.group(1)}';
  final top = RegExp(r'lib/([\w]+)/').firstMatch(p);
  return top == null ? 'lib' : top.group(1)!;
}

/// The `} on T {` clauses of [content] whose body neither traces nor
/// throws, each as its 1-based line.
List<int> untracedOnClauses(String content) => [
      for (final match in _onClause.allMatches(content))
        if (!_tracedBody.hasMatch(
          _catchBlockBody(content, match.start + 1) ?? '',
        ))
          '\n'.allMatches(content.substring(0, match.start)).length + 1,
    ];

/// Hand-written Dart of lib/ (the trace's own guards excepted, as above)
/// and of every package's library.
List<File> _scanned() => [
      for (final f in handWrittenDartFiles('lib'))
        if (!f.path.replaceAll('\\', '/').contains('lib/core/trace/')) f,
      for (final package in directoryNames('packages'))
        if (directoryAt('packages/$package/lib').existsSync())
          ...handWrittenDartFiles('packages/$package/lib'),
    ];

/// `} on T {` clauses that neither trace nor throw, per area, as counted
/// when #4410 started. A clause traced, rethrown or marked lowers its area:
/// write the new number; a new one is a defect.
const _untracedOnCeiling = <String, int>{
  'app': 3,
  'core': 19,
  'features/directory': 2,
  'features/me': 4,
  'features/money': 26,
  'features/profile': 2,
  'features/reservations': 6,
  'features/stock': 2,
  'features/task_recorder': 10,
  'features/workspace': 12,
  'packages/deskilo_task_recording': 2,
};

/// `// trace-exempt:` markers per area. Down only.
const _exemptCeiling = <String, int>{
  'core': 51,
  'features/auth': 3,
  'features/directory': 7,
  'features/help': 2,
  'features/mcp': 6,
  'features/me': 9,
  'features/money': 28,
  'features/reservations': 13,
  'features/workspace': 32,
  'packages/deskilo_tax_reference': 2,
};

Map<String, int> _perArea(Iterable<(String, int)> hits) {
  final out = <String, int>{};
  for (final (path, n) in hits) {
    if (n == 0) continue;
    out.update(_areaOf(path), (v) => v + n, ifAbsent: () => n);
  }
  return out;
}

/// The areas whose count differs from [ceiling], in words.
List<String> _ratchet(Map<String, int> actual, Map<String, int> ceiling) => [
      for (final area in {...actual.keys, ...ceiling.keys}.toList()..sort())
        if ((actual[area] ?? 0) != (ceiling[area] ?? 0))
          '$area: ${actual[area] ?? 0} (ceiling ${ceiling[area] ?? 0})',
    ];

void main() {
  group('#4410 — the clause without catch', () {
    test('a clause that returns a default is found, a traced one is not', () {
      expect(
        untracedOnClauses('''
int? f(String s) {
  try {
    return int.parse(s);
  } on FormatException {
    return null;
  }
}
'''),
        [4],
      );
      expect(
        untracedOnClauses('''
int? g(String s) {
  try {
    return int.parse(s);
  } on FormatException {
    // trace-exempt: a value typed by hand that is not a number is no value
    return null;
  } on StateError catch (e, st) {
    TraceLogger.instance.error('x', 'y', error: e, stackTrace: st);
    return null;
  }
}
'''),
        isEmpty,
      );
    });

    test('a marker without its reason is found', () {
      expect(_exemptWithoutReason.hasMatch('  // trace-exempt:\n'), isTrue);
      expect(
        _exemptWithoutReason.hasMatch('  // trace-exempt: parse fallback\n'),
        isFalse,
      );
    });

    test('the untraced clauses per area only fall', () {
      final actual = _perArea([
        for (final f in _scanned())
          (f.path, untracedOnClauses(f.readAsStringSync()).length),
      ]);
      expect(
        _ratchet(actual, _untracedOnCeiling),
        isEmpty,
        reason: 'a clause `} on T {` neither traces nor throws: trace it '
            '(error: and stackTrace: need `on T catch (e, st)`), rethrow, or '
            'mark it `// trace-exempt: <reason>`; when one was fixed, lower '
            'its area in _untracedOnCeiling.\n$actual',
      );
    });

    test('#4416 — no catch body prints past the redactor', () {
      final printing = RegExp(r'\bdebugPrint\(');
      final facade = RegExp(
        r'TraceLogger|\bActTrace\.|\btrace[A-Z]\w*\('
        r'|\b(?:logger|trace)\.(?:error|warn|log)\(',
      );
      final clause = RegExp(r'\bcatch\s*\(|\}\s*on\s+[\w.<>?, ]+\{');
      final hits = <String>[];
      for (final f in handWrittenDartFiles('lib')) {
        final content = f.readAsStringSync();
        for (final m in clause.allMatches(content)) {
          final body = _catchBlockBody(content, m.start + 1) ?? '';
          if (printing.hasMatch(body) && !facade.hasMatch(body)) {
            final line =
                '\n'.allMatches(content.substring(0, m.start)).length + 1;
            hits.add('${f.path}:$line');
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'debugPrint writes past lib/core/trace/redaction.dart: '
            'log through TraceLogger instead.\n${hits.join('\n')}',
      );
    });

    test('trace-exempt markers per area only fall, and each gives its reason',
        () {
      final files = [...handWrittenDartFiles('lib'), ..._scanned()]
          .map((f) => f.path)
          .toSet();
      final texts = {for (final p in files) p: File(p).readAsStringSync()};
      final actual = _perArea([
        for (final e in texts.entries)
          (e.key, _exemptMarker.allMatches(e.value).length),
      ]);
      final bare = [
        for (final e in texts.entries)
          if (_exemptWithoutReason.hasMatch(e.value)) e.key,
      ];
      expect(bare, isEmpty, reason: 'a trace-exempt marker without a reason');
      expect(
        _ratchet(actual, _exemptCeiling),
        isEmpty,
        reason: 'trace-exempt markers per area changed; lower the ceiling '
            'when one left, never raise it.\n$actual',
      );
    });
  });

  test('no silent catch (_) {} anywhere in lib/', () {
    final violations = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final content = file.readAsStringSync();
      if (_silentCatch.hasMatch(content)) {
        violations.add(file.path);
      }
    }
    expect(violations, isEmpty, reason: 'Silent catches in: $violations');
  });

  test('every catch captures the stack trace (catch (e, st))', () {
    final violations = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _singleParamCatch.firstMatch(lines[i]);
        if (match == null) continue;
        violations.add('${file.path}:${i + 1}');
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'catch without stack trace in: $violations — '
          'use catch (e, st) and log st, or carry it on with '
          'Error.throwWithStackTrace.',
    );
  });

  test('every catch block traces through TraceLogger (#145)', () {
    final violations = <String>[];
    for (final file in handWrittenDartFiles('lib')) {
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
