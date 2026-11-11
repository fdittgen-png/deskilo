// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3739 -- scripts/install_or_skip.sh: a tool a non-required workflow needs
// from the package mirror. Present: nothing to do. Mirror unreachable on a
// pull request: the job says it checked nothing and lets the workflow skip
// (available=false, exit 0). On any other event it fails, so master is never
// reported as checked when it was not.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late File output;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('install_or_skip');
    output = File('${tmp.path}/output')..createSync();
    // A `sudo` that always fails stands for the unreachable mirror; nothing
    // real is ever installed by this test.
    File('${tmp.path}/sudo')
      ..writeAsStringSync('#!/bin/sh\nexit 100\n')
      ..createSync();
    Process.runSync('chmod', ['+x', '${tmp.path}/sudo']);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult run(String command, String event) => Process.runSync(
    'bash',
    ['scripts/install_or_skip.sh', command, 'some-package'],
    environment: {
      'PATH': '${tmp.path}:/usr/bin:/bin',
      'GITHUB_OUTPUT': output.path,
      'GITHUB_STEP_SUMMARY': '${tmp.path}/summary',
      'GITHUB_EVENT_NAME': event,
      'INSTALL_RETRY_PAUSE_SECONDS': '0',
    },
    includeParentEnvironment: false,
  );

  test('a tool that is already there needs no mirror', () {
    final result = run('bash', 'pull_request');
    expect(result.exitCode, 0);
    expect(output.readAsStringSync().trim(), 'available=true');
  });

  test('an unreachable mirror on a pull request skips with a notice', () {
    final result = run('a-tool-that-does-not-exist', 'pull_request');
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(output.readAsStringSync().trim(), 'available=false');
    expect('${result.stdout}', contains('::warning title=Nothing was checked'));
    expect(
      File('${tmp.path}/summary').readAsStringSync(),
      contains('Nothing was checked'),
    );
  });

  test('an unreachable mirror on master fails the job', () {
    final result = run('a-tool-that-does-not-exist', 'push');
    expect(result.exitCode, 1);
    expect(output.readAsStringSync().trim(), isEmpty);
    expect('${result.stdout}', contains('::error::'));
  });
}
