// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2394 — an MCP operation is named in Dart through the generated
// McpOperationId, never as a string literal: a renamed or removed
// operation then fails to compile instead of silently matching nothing.
// The MCP code (features/mcp, core/mcp, core/instance/mcp_*) is scanned;
// generated files carry the names by construction.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `path:line: id` for every catalogued id quoted in [sources].
List<String> mcpOperationLiterals(
  Map<String, String> sources,
  Iterable<String> ids,
) {
  final pattern = RegExp('[\'"](${ids.map(RegExp.escape).join('|')})[\'"]');
  return [
    for (final e in sources.entries)
      for (final (i, line) in e.value.split('\n').indexed)
        for (final m in pattern.allMatches(line))
          '${e.key}:${i + 1}: ${m.group(1)}',
  ];
}

void main() {
  final contract = jsonDecode(
    File('contracts/mcp/operations.json').readAsStringSync(),
  ) as Map;
  final ids = [
    for (final o in contract['operations'] as List) '${(o as Map)['id']}',
  ];

  test('no MCP operation id is a string literal in the MCP code', () {
    bool scanned(String path) =>
        path.endsWith('.dart') &&
        !path.endsWith('.g.dart') &&
        !path.endsWith('mcp_operations.dart') &&
        (path.startsWith('lib/features/mcp/') ||
            path.startsWith('lib/core/mcp/') ||
            RegExp(r'^lib/core/instance/mcp_\w+\.dart$').hasMatch(path));
    final sources = {
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (scanned(f.path)) f.path: f.readAsStringSync(),
    };
    expect(sources, isNotEmpty);
    expect(
      mcpOperationLiterals(sources, ids),
      isEmpty,
      reason: 'name the operation as McpOperationId.<name> (its .id is the wire name)',
    );
  });

  test('the literal guard can fail', () {
    expect(
      mcpOperationLiterals({
        'x.dart': "final a = 'get_capabilities';\nfinal b = 'getCapabilities';",
      }, ids),
      ['x.dart:1: get_capabilities'],
    );
  });
}
