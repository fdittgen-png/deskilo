// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1632 — the MCP coverage gate (see mcp_coverage/coverage.dart).
//
//   dart run tool/mcp_coverage.dart                       # the map only
//   dart run tool/mcp_coverage.dart --pgtap report-pgtap.log --sha <commit>
//
// Exit 0: every implemented tool is covered (and, with --pgtap, every
// required pgTAP file ran and passed at that commit). Exit 1: the gate
// failed, each reason on stderr. Exit 2: the inputs are unreadable.
import 'dart:convert';
import 'dart:io';

import 'mcp_coverage/coverage.dart';

void main(List<String> args) => exitCode = run(args);

int run(List<String> args) {
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final pgtap = option('pgtap');
  final sha = option('sha');
  if (pgtap != null && sha == null) {
    stderr.writeln(
      'usage: dart run tool/mcp_coverage.dart [--pgtap <log> --sha <commit>]',
    );
    return 2;
  }
  final Map<String, dynamic> coverage;
  final List<int> contractBytes;
  try {
    coverage = jsonDecode(
      File(coveragePath).readAsStringSync(),
    ) as Map<String, dynamic>;
    contractBytes = File(contractPath).readAsBytesSync();
  } on Object catch (e) {
    stderr.writeln('mcp coverage: cannot read the inputs: $e');
    return 2;
  }
  final contract =
      jsonDecode(utf8.decode(contractBytes)) as Map<String, dynamic>;
  final fingerprint = contractFingerprint(contractBytes);
  String? read(String path) {
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  final problems = validateCoverage(coverage, contract, fingerprint, read);
  if (pgtap != null) {
    problems.addAll(checkPgtapEvidence(coverage, read(pgtap), sha!));
  }
  for (final p in problems) {
    stderr.writeln('::error::mcp coverage: $p');
  }
  final ops = implementedOperations(contract).length;
  final files = requiredPgtap(coverage).length;
  stdout.writeln(
    'mcp coverage: $ops implemented operations, contract '
    '${fingerprint.substring(0, 12)}'
    '${pgtap == null ? '' : ', $files required pgTAP files at $sha'}'
    ' — ${problems.isEmpty ? 'holds' : '${problems.length} problem(s)'}',
  );
  return problems.isEmpty ? 0 : 1;
}
