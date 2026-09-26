// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 — regenerates the MCP operation contract's four renderings from
// contracts/mcp/operations.json. `test/tool/mcp_contract_test.dart` fails
// when a committed rendering is not what this writes.
import 'dart:convert';
import 'dart:io';

import 'mcp_contract/render.dart';

void main() {
  final source = File('contracts/mcp/operations.json');
  if (!source.existsSync()) {
    stderr.writeln('contracts/mcp/operations.json is missing');
    exitCode = 2;
    return;
  }
  final contract = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  for (final entry in renderMcpContract(contract).entries) {
    final file = File(entry.key)..parent.createSync(recursive: true);
    if (!file.existsSync() || file.readAsStringSync() != entry.value) {
      file.writeAsStringSync(entry.value);
      stdout.writeln('wrote ${entry.key}');
    }
  }
}
