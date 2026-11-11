// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3677 -- a tool or AI mention in a commit message or a pull request's title
// or text fails the static gates, naming the commit or the text and the line.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory repo;
  late String script;
  var counter = 0;

  ProcessResult git(List<String> args) =>
      Process.runSync('git', args, workingDirectory: repo.path);

  String commit(String message, {String date = '2026-11-12T12:00:00Z'}) {
    File('${repo.path}/f').writeAsStringSync('$message${counter++}');
    git(['add', '-A']);
    Process.runSync(
      'git',
      ['commit', '-q', '-m', message],
      workingDirectory: repo.path,
      environment: {'GIT_AUTHOR_DATE': date, 'GIT_COMMITTER_DATE': date},
    );
    return (git(['rev-parse', 'HEAD']).stdout as String).trim();
  }

  ProcessResult check(String base, String head, {Map<String, String>? env}) =>
      Process.runSync(
        'bash',
        [script],
        workingDirectory: repo.path,
        environment: {'BASE': base, 'HEAD': head, ...?env},
      );

  setUpAll(() {
    script = File('scripts/tool_lines_check.sh').absolute.path;
    repo = Directory.systemTemp.createTempSync('toollines');
    git(['init', '-q']);
    git(['config', 'user.email', 'a@b.c']);
    git(['config', 'user.name', 'a']);
  });
  tearDownAll(() => repo.deleteSync(recursive: true));

  test('a clean range and a clean text pass', () {
    final base = commit('first');
    final head = commit('fix: a clean message\n\nCloses #1');
    final r = check(base, head, env: {'PR_TITLE': 'fix: x', 'PR_BODY': 'text'});
    expect(r.exitCode, 0, reason: '${r.stdout}');
  });

  test('a footer, a session link and a trailer in a commit fail, named', () {
    final base = commit('second');
    for (final line in [
      'Generated with Claude Code',
      'Co-Authored-By: Claude <noreply@anthropic.com>',
      'Claude-Session: https://claude.ai/code/session_x',
    ]) {
      final head = commit('fix: x\n\nbody\n\n$line');
      final r = check(base, head);
      expect(r.exitCode, 1, reason: line);
      expect('${r.stdout}', contains('commit ${head.substring(0, 9)}'));
    }
  });

  test('a planted line in the pull request text or title fails', () {
    final base = commit('third');
    final head = commit('fix: y');
    final body = check(base, head, env: {'PR_BODY': 'ok\n\u{1F916} Generated with [Claude Code](x)'});
    expect(body.exitCode, 1);
    expect('${body.stdout}', contains('the pull request text'));
    final title = check(
      base,
      head,
      env: {'PR_TITLE': 'Generated with Claude Code'},
    );
    expect(title.exitCode, 1);
    expect('${title.stdout}', contains('the pull request title'));
  });

  test('a phrase in prose and a person named Claude are not tool lines', () {
    final base = commit('fourth');
    final head = commit(
      'fix: x\n\nThe report is generated with the nightly job.\n\n'
      'Co-Authored-By: Claude Martin <claude.martin@example.org>\n'
      'Reviewed in a Claude Code session note kept out of the text? no.',
    );
    final r = check(base, head);
    expect(r.exitCode, 0, reason: '${r.stdout}');
  });

  test('the footer and the address trailer fail only in their shapes', () {
    final base = commit('fifth');
    for (final line in [
      '\u{1F916} Generated with [Claude Code](https://example.org)',
      'Generated with Claude Code',
      'Co-authored-by: Anyone <noreply@anthropic.com>',
    ]) {
      final r = check(base, commit('fix: z\n\n$line'));
      expect(r.exitCode, 1, reason: line);
    }
  });

  test('a range that cannot be read fails loudly, not as a pass', () {
    commit('sixth');
    final r = check('0123456789abcdef0123456789abcdef01234567', 'HEAD');
    expect(r.exitCode, 2, reason: '${r.stdout}');
    expect('${r.stdout}', contains('cannot be read'));
  });

  test('an edit of the pull request text is checked too', () {
    final text = File('.github/workflows/tool-lines.yml').readAsStringSync();
    expect(text, contains('edited'));
    expect(text, contains('scripts/tool_lines_check.sh'));
  });

  test('a commit authored before the rule passes, the same after it fails', () {
    final base = commit('seventh');
    const line = 'Co-Authored-By: Claude <noreply@anthropic.com>';
    final before = commit('old\n\n$line', date: '2026-11-10T12:00:00Z');
    expect(check(base, before).exitCode, 0, reason: 'older commits stay');
    final after = commit('new\n\n$line', date: '2026-11-11T06:00:00Z');
    expect(check(base, after).exitCode, 1);
  });

  test('the static job runs it on a pull request and on a push', () {
    final text = File('.github/workflows/quality.yml').readAsStringSync();
    expect(text, contains('scripts/tool_lines_check.sh'));
    expect(text, contains('PR_BODY: \${{ github.event.pull_request.body }}'));
    expect(text, contains('github.event.before'));
  });
}
