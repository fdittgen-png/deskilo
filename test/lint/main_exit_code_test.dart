// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — a tool's exit code is what CI gates on, and Dart ignores
// what `main` returns: `int main() => 1` exits 0. Six tools relied on
// exactly that — the classifier's usage error, the quality rows' stream
// violation, the preflight's "commit this" and "a generator failed",
// the applied-migrations recorder, the instance and media CLIs — and
// the first throwaway run of a dying classifier passed its step because
// of it. The invariant: no tool declares `main` with a return type, and
// the one whose exit code the quality gate reads really does exit
// nonzero over a broken stream.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no tool returns its exit code from main — Dart ignores it', () {
    final offenders = <String>[];
    for (final root in ['tool', 'scripts']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (RegExp(r'^(int|Future<int>)\s+main\s*\(', multiLine: true)
            .hasMatch(f.readAsStringSync())) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'these declare `int main` — the value is dropped and the '
            'process exits 0. Write `void main(args) => exitCode = run(args);`');
  });

  test('the quality rows tool exits 1 over an empty stream — the gate reads '
      'the process, not the rows', () {
    final dir = Directory.systemTemp.createTempSync('rows-exit');
    try {
      final events = File('${dir.path}/tests.jsonl')..writeAsStringSync('');
      final r = Process.runSync('dart', [
        'run', 'tool/quality_rows.dart',
        '--events', events.path,
        '--exit-code', '0',
        '--manifest', '.github/quality-manifest.psv',
        '--out', '${dir.path}/tests.psv',
      ]);
      expect(r.exitCode, 1, reason: '${r.stdout}${r.stderr}');
      expect(File('${dir.path}/tests.psv').readAsStringSync(),
          contains('|failure|'),
          reason: 'the rows are still written, red, so the report says why');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
