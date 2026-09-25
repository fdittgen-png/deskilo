// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1634 — validates `docs/product/capabilities.json` and writes the
// capability page and the release artifact from it.
//
//   dart run tool/capability_evidence.dart          # rewrite the outputs
//   dart run tool/capability_evidence.dart --check  # exit 1 on drift
//
// An invalid manifest exits 2 and writes nothing: there is no partial
// publication. Two runs on the same tree are byte-identical.
import 'dart:convert';
import 'dart:io';

import 'capability_evidence/evidence.dart';
import 'capability_evidence/render.dart';

void main(List<String> args) {
  final check = args.contains('--check');
  final ctx = Context.load('.');
  final file = File(manifestPath);
  if (!file.existsSync()) {
    stderr.writeln('$manifestPath: missing');
    exit(2);
  }
  final manifest =
      (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  final problems = validate(manifest, ctx);
  if (problems.isNotEmpty) {
    for (final p in problems) {
      stderr.writeln('$manifestPath: $p');
    }
    stderr.writeln('${problems.length} problem(s); nothing written');
    exit(2);
  }
  final projection = project(manifest, ctx);
  var drift = false;
  for (final (path, out) in [
    (pagePath, renderPage(projection)),
    (releasePath, renderRelease(projection)),
  ]) {
    final f = File(path);
    if (out == (f.existsSync() ? f.readAsStringSync() : null)) continue;
    drift = true;
    if (check) {
      stderr.writeln('$path: out of date');
    } else {
      f.writeAsStringSync(out);
      stdout.writeln('wrote $path');
    }
  }
  if (check && drift) exit(1);
  final caps = (projection['capabilities'] as List).cast<Map<String, Object?>>();
  stdout.writeln('${caps.length} capabilities, '
      '${caps.where((c) => c['status'] == 'shipped').length} shipped');
}
