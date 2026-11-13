// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3516 -- tool/country_coverage.dart against fixture repositories: a changed
// country line that no test ran is reported, one that ran is clean, and
// anything the check cannot read is a failure, never a pass.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/country_coverage.dart';
import '../helpers/tool_process.dart';

late Directory _repo;

ProcessResult _git(List<String> args) => Process.runSync(
  'git',
  ['-c', 'user.email=t@example.org', '-c', 'user.name=t', '-c', 'commit.gpgsign=false', ...args],
  workingDirectory: _repo.path,
);

String _commit(Map<String, String?> files) {
  files.forEach((path, text) {
    final f = File('${_repo.path}/$path');
    if (text == null) {
      f.deleteSync();
      return;
    }
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  });
  _git(['add', '-A']);
  _git(['commit', '-q', '-m', 'c']);
  return '${_git(['rev-parse', 'HEAD']).stdout}'.trim();
}

String _lcov(Map<String, Map<int, int>> files) => [
  for (final e in files.entries) ...[
    'SF:${_repo.path}/${e.key}',
    for (final d in e.value.entries) 'DA:${d.key},${d.value}',
    'LF:${e.value.length}',
    'LH:${e.value.values.where((h) => h > 0).length}',
    'end_of_record',
  ],
  '',
].join('\n');

class _Run {
  _Run(this.code, this.out, this.line);
  final int code;
  final String out;
  final String line;
}

/// Runs the check over base..HEAD with [lcov] text (null: no lcov file).
_Run _check(String base, String? lcov, {String? candidate}) {
  final lcovPath = '${_repo.path}/lcov.info';
  if (lcov != null) File(lcovPath).writeAsStringSync(lcov);
  final lineOut = '${_repo.path}/line.txt';
  final head = '${_git(['rev-parse', 'HEAD']).stdout}'.trim();
  final captured = StringBuffer();
  final code = run(
    ['--lcov', lcovPath, '--base', base, '--candidate', candidate ?? head, '--line-out', lineOut],
    workingDirectory: _repo.path,
    out: captured,
  );
  final lineFile = File(lineOut);
  return _Run(code, '$captured', lineFile.existsSync() ? lineFile.readAsStringSync().trim() : '');
}

void main() {
  setUp(() {
    _repo = Directory.systemTemp.createTempSync('country_cov');
    _git(['init', '-q']);
  });
  tearDown(() => _repo.deleteSync(recursive: true));

  const before = 'bool f(String c) {\n  return c.isEmpty;\n}\n';
  // line 2 is the new comparison
  const after = "bool f(String c) {\n  if (c == 'IT') return true;\n  return c.isEmpty;\n}\n";

  test('a changed country line with no hit is reported, with its line', () {
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': after});
    final r = _check(base, _lcov({'lib/a.dart': {1: 4, 2: 0, 3: 4}}));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('file=lib/a.dart,line=2'));
    expect(r.line, '1 of 1 changed country lines not run by any test');
  });

  test('the same line with a hit is clean', () {
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': after});
    final r = _check(base, _lcov({'lib/a.dart': {1: 4, 2: 3, 3: 1}}));
    expect(r.code, 0, reason: r.out);
    expect(r.line, '1 changed country lines, none unrun');
  });

  test('a country line outside the diff is not this change\'s to cover', () {
    final base = _commit({'lib/a.dart': after});
    _commit({'lib/a.dart': '// a note\n$after'});
    // the literal moved to line 3 but its text did not change: line 1 is new
    final r = _check(base, _lcov({'lib/a.dart': {2: 4, 3: 0, 4: 4}}));
    expect(r.code, 0, reason: r.out);
    expect(r.line, 'no changed country line');
  });

  test('a comment, a doc comment and a path outside lib/ are ignored', () {
    final base = _commit({'lib/a.dart': before, 'test/t.dart': 'void main() {}\n'});
    _commit({
      'lib/a.dart': "// 'IT' rules\n/// 'FR' too\n$before",
      'test/t.dart': "void main() { print('DE'); }\n",
      'packages/p/lib/p.dart': "const x = 'ES';\n",
    });
    final r = _check(base, _lcov({'lib/a.dart': {4: 1}}));
    expect(r.code, 0, reason: r.out);
  });

  test('a literal on a continuation line takes its statement\'s first line', () {
    const multi = "bool f(String c) {\n  return c.isEmpty ||\n      c == 'IT';\n}\n";
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': multi});
    // no record on line 3: the statement starts on line 2
    final cold = _check(base, _lcov({'lib/a.dart': {1: 1, 2: 0}}));
    expect(cold.code, 1, reason: cold.out);
    expect(cold.out, contains('line=3'));
    final warm = _check(base, _lcov({'lib/a.dart': {1: 1, 2: 5}}));
    expect(warm.code, 0, reason: warm.out);
  });

  test('a literal no record covers is not executable and is not reported', () {
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': "const _only = {'IT'};\n$before"});
    final r = _check(base, _lcov({'lib/a.dart': {3: 1}}));
    expect(r.code, 0, reason: r.out);
  });

  test('a changed file no test loaded is reported, not skipped', () {
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': after, 'lib/b.dart': before});
    final r = _check(base, _lcov({'lib/b.dart': {1: 1}}));
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('no test loaded this file'));
  });

  test('a renamed file is read under its new path', () {
    final base = _commit({'lib/old.dart': after});
    _git(['mv', 'lib/old.dart', 'lib/new.dart']);
    _commit({'lib/new.dart': after.replaceFirst('return true', 'return false')});
    // the literal's line 2 changed by an edit that is not the literal: the
    // line is changed, so it is read, and it ran
    final r = _check(base, _lcov({'lib/new.dart': {1: 1, 2: 2, 3: 1}}));
    expect(r.code, 0, reason: r.out);
  });

  test('no lcov, an empty lcov and a malformed one fail closed', () {
    final base = _commit({'lib/a.dart': before});
    _commit({'lib/a.dart': after});
    final missing = _check(base, null);
    expect(missing.code, 1, reason: missing.out);
    expect(missing.line, startsWith('not measured'));
    final empty = _check(base, '');
    expect(empty.code, 1, reason: empty.out);
    final torn = _check(base, 'SF:lib/a.dart\nDA:2,0\n');
    expect(torn.code, 1, reason: torn.out);
    expect(torn.out, contains('not usable evidence'));
  });

  test('a tree that is not the candidate, or an unreadable base, is refused', () {
    final base = _commit({'lib/a.dart': before});
    final head = _commit({'lib/a.dart': after});
    final lcov = _lcov({'lib/a.dart': {1: 1, 2: 1, 3: 1}});
    final wrongTree = _check(base, lcov, candidate: base);
    expect(wrongTree.code, 2, reason: wrongTree.out);
    final badBase = _check('0123456789abcdef0123456789abcdef01234567', lcov);
    expect(badBase.code, 1, reason: badBase.out);
    expect(head, isNotEmpty);
  });

  test('changedLines reads added hunks of a -U0 diff', () {
    const diff = '--- a/lib/a.dart\n+++ b/lib/a.dart\n@@ -2,0 +3,2 @@\n+x\n+y\n'
        '@@ -9 +11 @@\n-a\n+b\n--- a/lib/gone.dart\n+++ /dev/null\n@@ -1 +0,0 @@\n-z\n';
    expect(changedLines(diff), {
      'lib/a.dart': {3, 4, 11},
    });
  });

  test('the process exits nonzero for an uncovered line (Dart ignores main)', () {
    final base = _commit({'lib/a.dart': before});
    final head = _commit({'lib/a.dart': after});
    File('${_repo.path}/lcov.info').writeAsStringSync(_lcov({'lib/a.dart': {2: 0}}));
    final r = runToolSync(
      'tool/country_coverage.dart',
      ['--lcov', '${_repo.path}/lcov.info', '--base', base, '--candidate', head],
      workingDirectory: _repo.path,
    );
    expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
  });
}
