// SPDX-License-Identifier: 0BSD
//
// HARD RULE #1: no hard-coded user-facing strings. Every Text() must go
// through AppLocalizations; a string literal is allowed only as the
// defensive English fallback after `?? `.
//
// Ratchet-to-zero baseline: files listed in _baseline are grandfathered.
// New violations fail; fixing a file means removing it from the baseline.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Grandfathered files → number of allowed violations. Ratchet DOWN only.
const Map<String, int> _baseline = {};

final _textLiteral = RegExp(r'''Text\(\s*['"]''');
final _fallbackLiteral = RegExp(r'''\?\?\s*['"]''');

void main() {
  test('no Text() with a hard-coded string literal outside the baseline', () {
    final violations = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('lib/l10n/'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      var count = 0;
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_textLiteral.hasMatch(line) && !_fallbackLiteral.hasMatch(line)) {
          count++;
          violations.add('${file.path}:${i + 1}: $line');
        }
      }
      final allowed = _baseline[file.path] ?? 0;
      if (count > allowed) {
        fail(
          '${file.path} has $count hard-coded Text() literal(s), '
          'baseline allows $allowed:\n${violations.join('\n')}\n'
          'Add the key to an ARB fragment instead (HARD RULE #1).',
        );
      }
    }
  });
}
