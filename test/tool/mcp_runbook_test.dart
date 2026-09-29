// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1633 — the MCP runbook in docs/guides/OPERATIONS.md is executed, not
// just written: every documented `mcp-*` line marked `# expect: exit N
// (target: STATE)` runs through the real command against a fixture in that
// state and must exit as the document says. A command the tool does not
// have, or a flag it refuses, fails here before an operator meets it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/instance/mcp_activation.dart';
import '../helpers/mcp_cli_fakes.dart';
import '../helpers/mcp_target_fixture.dart';

class _Out implements IOSink {
  final text = StringBuffer();
  @override
  void writeln([Object? obj = '']) => text.writeln(obj);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Splits a shell line on spaces, keeping "double quoted" words whole.
List<String> words(String line) => [
  for (final m in RegExp(r'"([^"]*)"|(\S+)').allMatches(line))
    m.group(1) ?? m.group(2)!,
];

void main() {
  final doc = File('docs/guides/OPERATIONS.md').readAsStringSync();
  final block =
      RegExp(r'```mcp\n(.*?)```', dotAll: true).firstMatch(doc)?.group(1) ?? '';
  final lines = RegExp(
    r'^dart run tool/instance\.dart (mcp-\S+[^#\n]*)#\s*expect: exit (\d) \(target: ([a-z-]+)\)',
    multiLine: true,
  ).allMatches(block).toList();

  test('the runbook documents the whole sequence', () {
    final documented = {for (final m in lines) m.group(1)!.split(' ').first};
    expect(documented, mcpCommands);
  });

  for (final m in lines) {
    final command = m.group(1)!.trim();
    final exit = int.parse(m.group(2)!);
    final state = m.group(3)!;
    test('$command (target: $state) exits $exit', () async {
      final argv = words(
        command
            .replaceAll('<ref>', fixtureRef)
            .replaceAll('<installation>', fixtureInstallation)
            .replaceAll('<epoch>', '1')
            .replaceAll('<workspace>', ws),
      );
      final api = target(
        database: readyDatabase(
          enabled: state == 'on' || state == 'pilot-fails',
        ),
      );
      final http = FakeHttp(
        anonymousStatus: state == 'unconfigured' ? 503 : 401,
        pilotAnswer: {
          'result': {
            'isError': false,
            'structuredContent': {
              'operation': 'get_capabilities',
              'workspace_id': ws,
              'status': 'completed',
              'data': state == 'pilot-fails'
                  ? {'email': 'x'}
                  : {'operations': <String>[]},
            },
          },
        },
      );
      final out = _Out();
      final code = await runMcp(
        argv,
        environment: env,
        api: api,
        http: http,
        release: (_) => fixtureRelease(),
        out: out,
      );
      expect(code, exit, reason: '${out.text}');
    });
  }
}
