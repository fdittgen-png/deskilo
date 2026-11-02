// SPDX-License-Identifier: AGPL-3.0-or-later
// Verify the required browser run independently from the VM shard stream.
import 'dart:convert';
import 'dart:io';

import 'quality_rows/rows.dart';

const browserSuite = 'test/browser/deployment_base_web_test.dart';

List<String> browserEvidenceProblems(String stream) {
  final run = readRun(stream);
  final problems = [...run.violations];
  final suite = run.suites[browserSuite];
  if (!run.completed || !run.success || run.testsFailed != 0 ||
      run.suites.length != 1 || suite == null || suite.passed < 1 || suite.skipped != 0) {
    problems.add('browser test did not run and pass completely');
  }
  var chrome = false;
  var suiteEvents = 0;
  for (final line in const LineSplitter().convert(stream)) {
    try {
      final event = jsonDecode(line);
      if (event is Map && event['type'] == 'suite' && event['suite'] is Map) {
        suiteEvents++;
        final data = event['suite'] as Map;
        if ('${data['path']}'.endsWith(browserSuite) && data['platform'] == 'chrome') chrome = true;
      }
    } on FormatException {
      // readRun reports malformed lines as violations.
    }
  }
  if (!chrome || suiteEvents != 1) problems.add('browser suite was not loaded once on Chrome');
  return problems;
}

void main(List<String> args) {
  if (args.length != 1 || !File(args.single).existsSync()) {
    stderr.writeln('browser test evidence is missing');
    exitCode = 1;
    return;
  }
  final problems = browserEvidenceProblems(File(args.single).readAsStringSync());
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
  }
}
