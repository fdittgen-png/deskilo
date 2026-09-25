// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — the classifier's invocation is fail-closed end to end: the
// real `scripts/ci_classify.sh` over a real git repository, through the
// real `tool/ci_classify.dart`, and every way the diff can be untrue —
// a base git cannot resolve, a HEAD it cannot diff, a classifier that
// dies, a verdict file with a line missing — ends in `required` or in a
// nonzero exit, never in `not_applicable`. The one green control is a
// docs-only change over a complete diff.
//
// Slow by design: each case is one `dart run`, because the thing under
// test is the invocation, not the function behind it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

late Directory _tmp;

/// A repository with one base commit and a second commit on top: a
/// presentation file renamed into `data/`, an adapter deleted, names with
/// a space and a newline, and 320 wiki pages — over the 300-file mark at
/// which an API listing would truncate. Returns the base sha.
String _repo(Directory dir, {required bool wide}) {
  void git(List<String> args) {
    final r = Process.runSync('git', ['-C', dir.path, ...args]);
    if (r.exitCode != 0) throw StateError('git $args: ${r.stderr}');
  }

  File('${dir.path}/docs/x.md').createSync(recursive: true);
  File('${dir.path}/lib/features/a/presentation/old.dart')
      .createSync(recursive: true);
  File('${dir.path}/lib/features/money/data/repo.dart')
      .createSync(recursive: true);
  git(['init', '-q']);
  git(['config', 'user.email', 'ci@example.invalid']);
  git(['config', 'user.name', 'ci']);
  git(['add', '-A']);
  git(['commit', '-q', '-m', 'base']);
  final base = Process.runSync('git', ['-C', dir.path, 'rev-parse', 'HEAD'])
      .stdout
      .toString()
      .trim();
  File('${dir.path}/docs/x.md').writeAsStringSync('changed\n');
  if (wide) {
    Directory('${dir.path}/lib/features/a/data').createSync();
    git(['mv', 'lib/features/a/presentation/old.dart', 'lib/features/a/data/new.dart']);
    git(['rm', '-q', 'lib/features/money/data/repo.dart']);
    File('${dir.path}/docs/a file.md').writeAsStringSync('space\n');
    File('${dir.path}/docs/two\nlines.md').writeAsStringSync('newline\n');
    for (var i = 0; i < 320; i++) {
      File('${dir.path}/docs/wiki/page_$i.md').createSync(recursive: true);
    }
  }
  git(['add', '-A']);
  git(['commit', '-q', '-m', 'change']);
  return base;
}

({int code, String out, String verdicts, String outputs}) _run(
  Directory repo,
  String base, {
  String event = 'pull_request',
  Map<String, String> env = const {},
}) {
  final out = Directory('${_tmp.path}/out')..createSync();
  final github = File('${_tmp.path}/github_output')..writeAsStringSync('');
  final r = Process.runSync(
    'bash',
    [
      'scripts/ci_classify.sh',
      '--event', event,
      '--base', base,
      '--out', out.path,
      '--repo', repo.path,
    ],
    environment: {'GITHUB_OUTPUT': github.path, ...env},
  );
  final verdicts = File('${out.path}/classification.txt');
  final result = (
    code: r.exitCode,
    out: '${r.stdout}${r.stderr}',
    verdicts: verdicts.existsSync() ? verdicts.readAsStringSync() : '',
    outputs: github.readAsStringSync(),
  );
  out.deleteSync(recursive: true);
  return result;
}

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('ci-classify'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  test('a complete diff over 300 files, with a rename, a deletion and '
      'awkward names, names the adapter and requires everything', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: true);
    final r = _run(repo, base);
    expect(r.code, 0, reason: r.out);
    expect(r.verdicts, contains('database|required|database-relevant: lib/'));
    expect(r.verdicts, contains('web|required|'));
    expect(r.outputs, contains('database=required\n'));
    expect(r.outputs, contains('web=required\n'));
  });

  test('the green control: a docs-only change over a complete diff '
      'stands both jobs down, with the verdict on record', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: false);
    final r = _run(repo, base);
    expect(r.code, 0, reason: r.out);
    expect(r.verdicts, contains('database|not_applicable|'));
    expect(r.verdicts, contains('web|not_applicable|'));
    expect(r.outputs, 'database=not_applicable\nweb=not_applicable\n');
  });

  test('a base git cannot resolve is not "nothing changed": everything '
      'is required', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    _repo(repo, wide: false);
    for (final base in ['', 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef']) {
      final r = _run(repo, base);
      expect(r.code, 0, reason: r.out);
      expect(r.verdicts, contains('database|required|the base commit is unknown'));
      expect(r.outputs, contains('web=required'), reason: 'base "$base"');
    }
  });

  test('a diff git cannot write is incomplete, and incomplete is required', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: false);
    // The base resolves; HEAD does not: an orphan branch has no commit.
    final orphan = Process.runSync(
        'git', ['-C', repo.path, 'checkout', '-q', '--orphan', 'nowhere']);
    expect(orphan.exitCode, 0, reason: orphan.stderr.toString());
    final r = _run(repo, base);
    expect(r.code, 0, reason: r.out);
    expect(r.verdicts, contains('database|required|the diff is incomplete'));
    expect(r.outputs, contains('web=required'));
  });

  test('a classifier that dies leaves no verdict and a red step — not a '
      'stood-down job', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: false);
    final broken = File('${_tmp.path}/broken.dart')
      ..writeAsStringSync("void main() => throw StateError('boom');\n");
    final r = _run(repo, base, env: {'CI_CLASSIFY_TOOL': broken.path});
    expect(r.code, isNot(0));
    expect(r.verdicts, isEmpty);
    expect(r.outputs, isEmpty,
        reason: 'no output line means every consumer runs its work');
  });

  test('a classifier that exits 0 and writes nothing is refused — the '
      'first CI run of a dying classifier passed exactly this way', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: false);
    final silent = File('${_tmp.path}/silent.dart')
      ..writeAsStringSync('void main() {}\n');
    final r = _run(repo, base, env: {'CI_CLASSIFY_TOOL': silent.path});
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains('wrote no'));
    expect(r.outputs, isEmpty);
  });

  test('a usage error is an exit code, not a verdict — Dart ignores what '
      '`int main` returns', () {
    final r = Process.runSync('dart', ['run', 'tool/ci_classify.dart']);
    expect(r.exitCode, 2, reason: '${r.stdout}${r.stderr}');
  });

  test('a verdict file with a discipline missing is refused, so a partial '
      'classification cannot stand anything down', () {
    final repo = Directory('${_tmp.path}/repo')..createSync();
    final base = _repo(repo, wide: false);
    final partial = File('${_tmp.path}/partial.dart')
      ..writeAsStringSync('''
import 'dart:io';
void main(List<String> a) {
  File(a[a.indexOf('--out') + 1]).writeAsStringSync('database|required|x|v0\\n');
}
''');
    final r = _run(repo, base, env: {'CI_CLASSIFY_TOOL': partial.path});
    expect(r.code, 1, reason: r.out);
    expect(r.out, contains("0 verdict lines for 'web'"));
  });
}
