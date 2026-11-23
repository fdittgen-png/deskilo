// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4420 -- the business-literals rule as a census. `business_literals_test` names a sample; this one
// counts, per file, the literal shapes in which a number that means something hides: a text width
// (`maxLength: 300`), a network timeout (`.timeout(const Duration(`), a policy window or wait
// (`Duration(days|seconds|minutes: n)` outside `domain/`), a page size (`limit: 100`), a bare
// ceiling (`1000000`). The counts are the baseline (business_literals_census.txt): a file may not
// gain one, and a fall must be written down. A number that means something is a named constant in
// its home, or a setting with a place in the interface; the sweep moves files out of the baseline.
//
// Write the baseline after a sweep:
//   flutter test test/lint/business_literals_census_test.dart --dart-define=WRITE_CENSUS=true
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';
import 'lint_sources.dart';

const _baselinePath = 'test/lint/business_literals_census.txt';
const _write = bool.fromEnvironment('WRITE_CENSUS');

/// The literal shapes counted (a name, the pattern, the paths it is not counted in).
final _kinds = <({String name, RegExp pattern, RegExp? except})>[
  (name: 'maxLength', pattern: RegExp(r'maxLength:\s*\d+'), except: null),
  (name: 'timeout', pattern: RegExp(r'\.timeout\(\s*const\s+Duration\('), except: null),
  (
    name: 'duration',
    pattern: RegExp(r'(?<!\.timeout\(\s*const\s+)Duration\(\s*(days|seconds|minutes):\s*\d+\s*\)'),
    except: RegExp(r'/domain/|_constants\.dart$|text_limits\.dart$|net_timeouts\.dart$|page_sizes\.dart$'),
  ),
  (name: 'limit', pattern: RegExp(r'\blimit:\s*\d{2,}'), except: null),
  (name: 'ceiling', pattern: RegExp(r'(?<![\d_.])1000000(?![\d_])'), except: null),
];

/// `kind|file` -> count over the hand-written `lib/` files.
Map<String, int> census(Iterable<File> files) {
  final out = <String, int>{};
  for (final f in files) {
    final path = f.path.replaceAll('\\', '/');
    final text = codeLines(f).join('\n');
    for (final k in _kinds) {
      if (k.except?.hasMatch(path) ?? false) continue;
      final n = k.pattern.allMatches(text).length;
      if (n > 0) out['${k.name}|$path'] = n;
    }
  }
  return out;
}

Map<String, int> _baseline() => {
  for (final line in File(_baselinePath).readAsLinesSync())
    if (line.trim().isNotEmpty && !line.startsWith('#'))
      line.substring(0, line.lastIndexOf('|')): int.parse(line.substring(line.lastIndexOf('|') + 1)),
};

void main() {
  test('a literal shape is counted per file, comments skipped, a home file excepted', () {
    final dir = Directory.systemTemp.createTempSync('census');
    try {
      final domain = File('${dir.path}/lib/x/domain/a.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('const d = Duration(days: 30);');
      final ui = File('${dir.path}/lib/x/b.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "// maxLength: 300\nTextField(maxLength: 300);\nfoo.timeout(const Duration(seconds: 12));\nwait(Duration(minutes: 5)); final n = 1000000; final m = 21000000;\nq(limit: 100);",
        );
      final out = census([domain, ui]);
      String key(String kind, File f) => '$kind|${f.path}';
      expect(out[key('maxLength', ui)], 1);
      expect(out[key('timeout', ui)], 1);
      expect(out[key('duration', ui)], 1);
      expect(out[key('limit', ui)], 1);
      expect(out[key('ceiling', ui)], 1);
      expect(out.keys.where((k) => k.endsWith(domain.path)), isEmpty, reason: 'a domain Duration is the domain\'s own');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('the census only falls: no file gains a literal, and a fall is written down', () {
    final actual = census(handWrittenDartFiles('lib'));
    if (_write) {
      final keys = actual.keys.toList()..sort();
      File(_baselinePath).writeAsStringSync([
        '# #4420 -- literals counted per file (kind|file|count). Only falls: a file may not gain one;',
        '# rewrite after a sweep with --dart-define=WRITE_CENSUS=true (see business_literals_census_test.dart).',
        for (final k in keys) '$k|${actual[k]}',
        '',
      ].join('\n'));
      return;
    }
    final baseline = _baseline();
    final rose = <String>[], fell = <String>[];
    for (final k in {...actual.keys, ...baseline.keys}) {
      final a = actual[k] ?? 0, b = baseline[k] ?? 0;
      if (a > b) rose.add('$k: $a > $b');
      if (a < b) fell.add('$k: $a < $b');
    }
    expect(
      rose,
      isEmpty,
      reason: 'a number that means something is a named constant in its home or a setting (#4420):\n${rose.take(25).join('\n')}',
    );
    expect(
      fell,
      isEmpty,
      reason: 'it fell: rewrite the baseline (flutter test test/lint/business_literals_census_test.dart --dart-define=WRITE_CENSUS=true):\n${fell.take(25).join('\n')}',
    );
  });
}
