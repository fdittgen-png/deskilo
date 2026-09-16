// SPDX-License-Identifier: 0BSD
//
// #1334 — writes docs/testing/TEST_INVENTORY.md: every test file,
// classified by the rules in tool/test_inventory/inventory.dart.
//
// Usage:
//   dart run tool/test_inventory.dart

import 'dart:io';

import 'test_inventory/inventory.dart';

void main() {
  final entries = classify();
  final file = File(inventoryPath)..parent.createSync(recursive: true);
  file.writeAsStringSync(render(entries));
  final flagged = entries.where((e) => e.action != 'KEEP').length;
  stdout
    ..writeln(
        'wrote $inventoryPath: ${entries.length} files, $flagged flagged for refactor')
    ..write(summary(entries));
}
