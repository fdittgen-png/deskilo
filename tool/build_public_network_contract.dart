// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — regenerates the public network contract's renderings from
// contracts/public_network/operations.json.
// `test/tool/public_network_contract_test.dart` fails when a committed
// rendering is not what this writes.
import 'dart:convert';
import 'dart:io';

import 'public_network_contract/render.dart';

void main() {
  final source = File('contracts/public_network/operations.json');
  if (!source.existsSync()) {
    stderr.writeln('contracts/public_network/operations.json is missing');
    exitCode = 2;
    return;
  }
  final contract =
      jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final support = jsonDecode(
    File('contracts/public_network/support.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final rendered = {
    ...renderPublicNetworkContract(contract),
    publicNetworkGeneratedPaths.supportMatrix: renderSupportMatrix(
      contract,
      support,
      (path) => File(path).readAsStringSync(),
    ),
  };
  for (final entry in rendered.entries) {
    final file = File(entry.key)..parent.createSync(recursive: true);
    if (!file.existsSync() || file.readAsStringSync() != entry.value) {
      file.writeAsStringSync(entry.value);
      stdout.writeln('wrote ${entry.key}');
    }
  }
}
