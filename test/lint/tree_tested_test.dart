// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3670 -- a push to master whose tree a pull request already tested green
// does not run Quality again: the lookup names the earlier run, a different
// tree or a failed or cancelled earlier run means the full run, and the
// workflow wires the answer in front of the eleven jobs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<({int code, String out})> _run(String tree, String stdin) async {
  final p = await Process.start('bash', ['scripts/tree_tested.sh', tree]);
  p.stdin.write(stdin);
  await p.stdin.close();
  final out = await p.stdout.transform(utf8.decoder).join();
  return (code: await p.exitCode, out: out.trim());
}

void main() {
  const rows =
      '412\taaa\tfailure\n'
      '411\tbbb\tsuccess\n'
      '410\tccc\tcancelled\n'
      '409\tbbb\tsuccess\n';

  test('the same tree tested green names that run', () async {
    final r = await _run('bbb', rows);
    expect(r.code, 0);
    expect(r.out, '411', reason: 'the newest of the green runs');
  });

  test('a different tree runs in full', () async {
    expect((await _run('zzz', rows)).code, 1);
  });

  test('a failed or cancelled earlier run does not count', () async {
    expect((await _run('aaa', rows)).code, 1);
    expect((await _run('ccc', rows)).code, 1);
  });

  test('no candidates at all runs in full', () async {
    expect((await _run('bbb', '')).code, 1);
  });

  test('the workflow looks first and skips only on a master push', () {
    final text = File('.github/workflows/quality.yml').readAsStringSync();
    expect(text, contains('scripts/tree_tested.sh'));
    expect(text, contains("github.event_name == 'push'"));
    expect(text, contains("needs.tested.outputs.skip != 'true'"));
  });
}
