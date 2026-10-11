// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2383 — prints the dead-code scan: every public top-level declaration in
// `lib/` that nothing references, or that only tests reference.
//
//   dart run tool/dead_code.dart
//
// The gate is `test/lint/dead_code_test.dart`, which holds the reviewed
// exceptions; this tool lists everything the scan sees, so a reviewer can
// tell a new finding from an old one.
import 'dart:io';

import 'dead_code/scan.dart';

void main(List<String> args) {
  final findings = scanDeadCode(Directory.current.path);
  for (final kind in DeadCodeKind.values) {
    final some = findings.where((f) => f.kind == kind).toList();
    stdout.writeln('${kind.name}: ${some.length}');
    for (final f in some) {
      stdout.writeln('  ${f.path}:${f.line}  ${f.name}');
    }
  }
}
