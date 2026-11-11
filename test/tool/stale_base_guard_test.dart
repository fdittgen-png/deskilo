// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3688 -- a branch that puts recently merged files back to their earlier
// content fails the guard; a normal merge, an edit and a revert do not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory repo;
  var clock = 0;

  ProcessResult git(List<String> args) => Process.runSync(
    'git',
    args,
    workingDirectory: repo.path,
    environment: {
      'GIT_AUTHOR_DATE': '2026-11-12T12:00:${(clock % 60).toString().padLeft(2, '0')}Z',
      'GIT_COMMITTER_DATE': '2026-11-12T12:00:${(clock++ % 60).toString().padLeft(2, '0')}Z',
    },
  );

  void write(String name, String? text) {
    final f = File('${repo.path}/$name');
    if (text == null) {
      f.deleteSync();
    } else {
      f.writeAsStringSync(text);
    }
  }

  void commit(String message) {
    git(['add', '-A']);
    git(['commit', '-q', '-m', message]);
  }

  String head() => '${git(['rev-parse', 'HEAD']).stdout}'.trim();

  ProcessResult guard({String title = 'feat: x'}) => Process.runSync(
    'dart',
    [
      'run',
      '${Directory.current.path}/tool/stale_base_guard.dart',
      '--head',
      'HEAD',
      '--base',
      'master',
      '--title',
      title,
    ],
    workingDirectory: repo.path,
  );

  setUp(() {
    repo = Directory.systemTemp.createTempSync('stalebase');
    git(['init', '-q', '-b', 'master']);
    git(['config', 'user.email', 'a@b.c']);
    git(['config', 'user.name', 'a']);
    for (final n in ['a', 'b', 'c', 'd']) {
      write('$n.txt', 'old $n');
    }
    commit('base');
    git(['checkout', '-q', '-b', 'feature']);
    write('mine.txt', 'my work');
    commit('feature work');
    git(['checkout', '-q', 'master']);
    // master moves on: four files change, one is deleted.
    for (final n in ['a', 'b', 'c']) {
      write('$n.txt', 'new $n');
    }
    write('d.txt', null);
    commit('master: rework four files');
    write('e.txt', 'late');
    commit('master: add e');
  });
  tearDown(() => repo.deleteSync(recursive: true));

  test('a branch merged normally with master passes', () {
    git(['checkout', '-q', 'feature']);
    git(['merge', '-q', 'master', '-m', 'merge master']);
    final r = guard();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('a branch reset onto master and committed with its old tree fails', () {
    git(['checkout', '-q', 'feature']);
    final old = Directory('${repo.path}/.old')..createSync();
    for (final n in ['a', 'b', 'c', 'd']) {
      File('${old.path}/$n.txt').writeAsStringSync('old $n');
    }
    git(['reset', '-q', '--soft', 'master']);
    for (final n in ['a', 'b', 'c', 'd']) {
      write('$n.txt', 'old $n');
    }
    old.deleteSync(recursive: true);
    commit('feature: work');
    final r = guard();
    expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    final master = '${git(['rev-parse', '--short=9', 'master~1']).stdout}'.trim();
    expect('${r.stdout}', contains(master));
    expect('${r.stdout}', contains('Merge origin/master'));
  });

  test('the same with a title starting with Revert passes', () {
    git(['checkout', '-q', 'feature']);
    git(['reset', '-q', '--soft', 'master']);
    for (final n in ['a', 'b', 'c', 'd']) {
      write('$n.txt', 'old $n');
    }
    commit('feature: work');
    expect(guard(title: 'Revert "master: rework"').exitCode, 0);
  });

  test('a branch that really edits two of the files passes (edited, not '
      'restored)', () {
    git(['checkout', '-q', 'feature']);
    git(['merge', '-q', 'master', '-m', 'merge master']);
    write('a.txt', 'my edit a');
    write('b.txt', 'my edit b');
    commit('feature: edits');
    final r = guard();
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  });

  test('a file deleted on master and brought back counts as restored', () {
    git(['checkout', '-q', 'feature']);
    git(['reset', '-q', '--soft', 'master']);
    write('d.txt', 'old d');
    write('a.txt', 'old a');
    write('b.txt', 'old b');
    commit('feature: work');
    final r = guard();
    expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
    expect('${r.stdout}', contains('d.txt'));
  });

  test('the head helper reads a commit', () {
    expect(head(), isNotEmpty);
  });
}
