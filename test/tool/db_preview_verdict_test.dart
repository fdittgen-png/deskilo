// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3751 -- the verdict of the database preview: green only when every check
// succeeded; a check that did not run is not a success, and each failure says
// which file of the artifact to commit.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

ProcessResult _verdict(Map<String, String> outcomes) => Process.runSync(
  'bash',
  ['scripts/db_preview_verdict.sh'],
  environment: {...outcomes, 'GITHUB_STEP_SUMMARY': '', 'GITHUB_RUN_ID': '42'},
);

const _allGreen = {
  'REPLAY': 'success',
  'POLICIES': 'success',
  'CONTRACT': 'success',
  'PGTAP': 'success',
};

void main() {
  test('every check succeeded: exit 0, nothing to commit', () {
    final r = _verdict(_allGreen);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('Every check succeeded'));
    expect(r.stdout, isNot(contains('gh run download')));
  });

  test('a stale contract: exit 1, the file to commit and the download line',
      () {
    final r = _verdict({..._allGreen, 'CONTRACT': 'failure'});
    expect(r.exitCode, 1);
    expect(r.stdout, contains('| Effective contract | failure |'));
    expect(r.stdout, contains('assets/instance/contract.txt'));
    expect(r.stdout, contains('gh run download 42 -n database-preview'));
    expect(r.stdout, contains('| Policies | ok |'));
  });

  test('a failed replay skips the rest: none of them counts as a success', () {
    final r = _verdict({
      'REPLAY': 'failure',
      'POLICIES': 'skipped',
      'CONTRACT': 'skipped',
      'PGTAP': 'skipped',
    });
    expect(r.exitCode, 1);
    expect(r.stdout, contains('| Migration replay | failure |'));
    expect(r.stdout, contains('| Database tests | skipped |'));
  });

  test('an outcome that never arrived is "not run", and red', () {
    final r = _verdict({..._allGreen, 'PGTAP': ''});
    expect(r.exitCode, 1);
    expect(r.stdout, contains('| Database tests | not run |'));
  });

  test('the same lines reach the run summary', () {
    final dir = Directory.systemTemp.createTempSync('db_preview_verdict');
    addTearDown(() => dir.deleteSync(recursive: true));
    final summary = File('${dir.path}/summary.md');
    final r = Process.runSync(
      'bash',
      ['scripts/db_preview_verdict.sh'],
      environment: {..._allGreen, 'GITHUB_STEP_SUMMARY': summary.path},
    );
    expect(r.exitCode, 0);
    expect(summary.readAsStringSync(), contains('### Database preview'));
    expect(summary.readAsStringSync(), contains('| Effective contract | ok |'));
  });
}
