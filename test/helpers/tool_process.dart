// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3734 — the one way a test starts a repository tool as a process:
// `dart <file>`, never `dart run`. `dart run` first checks the package
// resolution and runs the build hooks under `.dart_tool`; two shards doing
// that at the same moment collide (exit 254, "File not formatted as yaml"),
// and the tool never runs. `dart <file>` uses the resolution already there.
// `test/lint/tool_process_test.dart` refuses `dart run tool/` elsewhere.
import 'dart:io';

/// The tool's absolute path, so a test may run it from a fixture directory.
String toolPath(String tool) =>
    File(tool).isAbsolute ? tool : '${Directory.current.path}/$tool';

/// Runs `dart <tool> <args>` and waits for it.
ProcessResult runToolSync(
  String tool,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) => Process.runSync(
  'dart',
  [toolPath(tool), ...args],
  workingDirectory: workingDirectory,
  environment: environment,
);

/// The asynchronous form of [runToolSync].
Future<ProcessResult> runTool(
  String tool,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) => Process.run(
  'dart',
  [toolPath(tool), ...args],
  workingDirectory: workingDirectory,
  environment: environment,
);
