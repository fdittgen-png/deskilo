// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3330 -- the one place a parity golden is read or rewritten.
//
// A golden is compared byte for byte and the directory must hold EXACTLY the
// files the test produced (a stale file is a failure, not a leftover). A run
// rewrites them only with `UPDATE_PARITY_GOLDENS=1`, and never under CI: an
// automated run can fail a change, it can never accept one. The rewrite is a
// reviewer-visible diff of the files.
import 'dart:convert' show Utf8Encoder;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Whether this run is allowed to rewrite goldens.
bool get _updating => Platform.environment['UPDATE_PARITY_GOLDENS'] == '1';

bool get _inCi => Platform.environment['CI'] == 'true';

/// Compares [text] (name -> UTF-8 text) and [bytes] (name -> raw bytes) with
/// the files of [dir]; with the update flag it rewrites them.
void expectParity({
  required String dir,
  Map<String, String> text = const {},
  Map<String, List<int>> bytes = const {},
}) {
  final produced = <String, List<int>>{
    for (final e in text.entries) e.key: _utf8(e.value),
    ...bytes,
  };
  if (_updating) {
    expect(
      _inCi,
      isFalse,
      reason:
          'UPDATE_PARITY_GOLDENS is refused under CI: a golden is '
          'accepted by a person, never by a run',
    );
    final d = Directory(dir)..createSync(recursive: true);
    for (final f in d.listSync().whereType<File>()) {
      if (!produced.containsKey(f.uri.pathSegments.last)) f.deleteSync();
    }
    for (final e in produced.entries) {
      File('$dir/${e.key}').writeAsBytesSync(e.value);
    }
    return;
  }
  final d = Directory(dir);
  final held = d.existsSync()
      ? {
          for (final f in d.listSync().whereType<File>())
            f.uri.pathSegments.last,
        }
      : <String>{};
  expect(
    held.toList()..sort(),
    produced.keys.toList()..sort(),
    reason:
        'the files of $dir are not the files the test produced '
        '(UPDATE_PARITY_GOLDENS=1 rewrites them deliberately)',
  );
  final differing = <String>[
    for (final e in produced.entries)
      if (!_same(File('$dir/${e.key}').readAsBytesSync(), e.value)) e.key,
  ];
  expect(
    differing,
    isEmpty,
    reason:
        'a writer no longer produces what it produced when the parity '
        'baseline was captured',
  );
}

List<int> _utf8(String s) => const Utf8Encoder().convert(s);

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
