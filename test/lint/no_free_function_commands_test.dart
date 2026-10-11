// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — a command is a class behind a provider (AGENT_RULES; the
// layering ratchet counts it only then). A top-level
// `Future<…> xxx(BuildContext context, WidgetRef ref, …)` in presentation
// resolves repositories itself, cannot be overridden in a test, and cannot
// be reused by the MCP or the task recorder, which need the operation
// without a BuildContext.
//
// The issue asked for all of them to move. Measured on 2026-10-11: 114 in
// 67 files, each a dialog-and-write flow whose write moves to an
// application/ class and whose dialog stays in a thin adapter — a rewrite
// per command, done when the command is next changed. Until then this
// holds the line: the count only goes down, and a new one fails here.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Free-function commands in presentation/ on 2026-10-11.
const _budget = 114;

void main() {
  test('free-function commands only go down (ratchet)', () {
    final command = RegExp(
      r'^(?:Future<[^\n]*?>|void)\s+(\w+)\(\s*BuildContext\s+\w+,\s*'
      r'WidgetRef\s+\w+',
      multiLine: true,
    );
    final hits = [
      for (final file in handWrittenDartFiles('lib'))
        if (file.path.contains('/presentation/'))
          for (final m in command.allMatches(file.readAsStringSync()))
            '${file.path}: ${m.group(1)}',
    ];
    expect(
      hits.length,
      lessThanOrEqualTo(_budget),
      reason:
          'a command is a class behind a provider in application/:\n'
          '${hits.join('\n')}',
    );
    expect(
      hits.length,
      _budget,
      reason: 'fewer free-function commands: lower _budget to ${hits.length}',
    );
  });
}
