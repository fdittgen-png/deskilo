// SPDX-License-Identifier: 0BSD
//
// #1191/#1192 — a Chip that carries an `avatar:` must not ALSO draw the
// selected checkmark. Material paints both, one on top of the other: the
// wizard's step number under a tick, the Alerts group-by glyph under
// one. What renders is a dark smudge where a symbol should be.
//
// The avatar IS the state on these chips, so the tick is suppressed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `ChoiceChip(`/`FilterChip(` in lib/, with the slice of source
/// that holds its arguments (the next 900 characters, which comfortably
/// covers the longest of them).
Iterable<({String file, int offset, String body})> _chips() sync* {
  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))) {
    final src = file.readAsStringSync();
    for (final m in RegExp(r'(ChoiceChip|FilterChip)\(').allMatches(src)) {
      final end = (m.start + 900).clamp(0, src.length);
      yield (file: file.path, offset: m.start, body: src.substring(m.start, end));
    }
  }
}

void main() {
  test('a chip with an avatar suppresses the duplicate checkmark', () {
    final offenders = <String>[];
    for (final chip in _chips()) {
      // Only the arguments of THIS chip: stop at the next chip.
      final next = RegExp(r'(ChoiceChip|FilterChip)\(')
          .firstMatch(chip.body.substring(1));
      final args =
          next == null ? chip.body : chip.body.substring(0, next.start + 1);
      if (!args.contains('avatar:')) continue;
      if (args.contains('showCheckmark: false')) continue;
      offenders.add('${chip.file} @ ${chip.offset}');
    }
    expect(offenders, isEmpty,
        reason: 'these chips draw their own tick over their avatar — add '
            '`showCheckmark: false`:\n${offenders.join('\n')}');
  });
}
