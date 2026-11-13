// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3872 -- scripts/merge_check.sh reports tool lines with the CI guard's own
// definition (scripts/tool_lines_check.sh), not a grep of its own: ordinary
// prose ("generated with the nightly job") and a human co-author are not tool
// lines, a real trailer is. Everything runs offline: a fake `gh` answers the
// pull request's title and body, a local bare repository is `origin`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _gate = 'Gate: analyze ok · lint ok · 3 listed tests ok';

void main() {
  late Directory root;
  late Directory work;
  late String script;

  ProcessResult git(List<String> args) =>
      Process.runSync('git', args, workingDirectory: work.path);

  void commit(String message) {
    File('${work.path}/f').writeAsStringSync('$message${DateTime.now()}');
    git(['add', '-A']);
    const date = '2026-11-12T12:00:00Z';
    final r = Process.runSync(
      'git',
      ['commit', '-q', '-m', message],
      workingDirectory: work.path,
      environment: {'GIT_AUTHOR_DATE': date, 'GIT_COMMITTER_DATE': date},
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
  }

  /// The merge check's result for a branch commit [message] and a pull
  /// request [body].
  ProcessResult check(String message, String body) {
    git(['checkout', '-q', '-B', 'feature', 'master']);
    commit(message);
    git(['push', '-q', '-f', 'origin', 'feature']);
    File('${root.path}/body').writeAsStringSync(body);
    return Process.runSync(
      'bash',
      [script, '1'],
      workingDirectory: work.path,
      environment: {
        'PATH': '${root.path}/bin:${Platform.environment['PATH']}',
        'FAKE_DIR': root.path,
      },
    );
  }

  setUpAll(() {
    script = File('scripts/merge_check.sh').absolute.path;
    root = Directory.systemTemp.createTempSync('merge_check_tools');
    Directory('${root.path}/bin').createSync();
    final gh = File('${root.path}/bin/gh')
      ..writeAsStringSync(r'''#!/usr/bin/env bash
case "$*" in
  *headRefName*) echo feature ;;
  *"--json title"*) echo "fix: x (Closes #1)" ;;
  *"--json body"*) cat "$FAKE_DIR/body" ;;
esac
''');
    Process.runSync('chmod', ['+x', gh.path]);
    Process.runSync('git', ['init', '-q', '--bare', '${root.path}/origin.git']);
    work = Directory('${root.path}/work')..createSync();
    git(['init', '-q', '-b', 'master']);
    git(['config', 'user.email', 'a@b.c']);
    git(['config', 'user.name', 'a']);
    git(['remote', 'add', 'origin', '${root.path}/origin.git']);
    commit('first');
    git(['push', '-q', 'origin', 'master']);
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  test('ordinary prose and a human co-author are not tool lines', () {
    final r = check(
      'fix: x\n\nCo-authored-by: Jane Doe <jane@example.com>',
      'The report is generated with the nightly job.\n\n$_gate\n',
    );
    expect(r.stdout, contains('tools:    0'), reason: '${r.stdout}');
    expect(r.stdout, contains('verdict:  OK'));
    expect(r.exitCode, 0);
  });

  test('a tool trailer in the commit or a footer in the body still fails', () {
    final commitLine = check(
      'fix: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>',
      '$_gate\n',
    );
    expect(commitLine.stdout, contains('verdict:  NOT OK'));
    expect(commitLine.stdout, isNot(contains('tools:    0')));
    final bodyLine = check(
      'fix: x',
      '$_gate\n\nGenerated with Claude Code\n',
    );
    expect(bodyLine.stdout, contains('verdict:  NOT OK'));
    expect(bodyLine.exitCode, isNot(0));
  });
}
