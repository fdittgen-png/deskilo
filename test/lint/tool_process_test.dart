// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3734 — a test starts a repository tool with `dart <file>` through
// `test/helpers/tool_process.dart`, never with `dart run tool/...`: `dart
// run` checks the resolution and runs the build hooks first, and shards
// doing that at once collide (exit 254, "File not formatted as yaml").
// A line that must keep `dart run` says so with `// dart-run-ok`.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The `'run', 'tool/` argument pairs in [source], by line, that do not
/// carry the `dart-run-ok` marker.
List<int> dartRunToolLines(String source) {
  final lines = source.split('\n');
  final found = <int>[];
  for (final m in RegExp(
    r"""['"]run['"],\s*['"](\$\{[^}]*\}/)?tool/""",
  ).allMatches(source)) {
    final line = '\n'.allMatches(source.substring(0, m.end)).length;
    if (!lines[line].contains('dart-run-ok')) found.add(line + 1);
  }
  return found;
}

void main() {
  test('the shape can fail: a planted call is found, a marked one is not', () {
    const planted = '''
Process.runSync('dart', ['run', 'tool/x.dart']);
Process.runSync('dart', [
  'run',
  'tool/y.dart',
]);
Process.run('dart', ['run', 'tool/z.dart']); // dart-run-ok
''';
    expect(dartRunToolLines(planted), [1, 4]);
  });

  test('no test starts a tool with dart run outside the helper', () {
    final offenders = <String>[];
    for (final f in handWrittenDartFiles('test')) {
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('test/helpers/tool_process.dart') ||
          path.endsWith('test/lint/tool_process_test.dart')) {
        continue;
      }
      for (final line in dartRunToolLines(f.readAsStringSync())) {
        offenders.add('$path:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'start the tool with runTool/runToolSync from '
          'test/helpers/tool_process.dart (dart <file>, no hooks)',
    );
  });
}
