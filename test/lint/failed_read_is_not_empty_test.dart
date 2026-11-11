// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3680 -- a failed read is never shown as an empty answer. `.value ?? const
// []` on an async read turns "the server did not answer" into "nothing
// there": paid invoices read as overdue, a blocked list as empty. Zero is only
// ever a successful answer; a source that failed is said, with a way to try
// again (AsyncReadBody / ReadFailureBanner).
//
// Counted per area, so a partial win is visible: the ceiling only falls, each
// use is replaced by a read that carries "failed" and "still reading" to the
// screen, or stays with a reason why an empty answer is right there (a
// `// empty-ok: <reason>` comment on the line).
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// The shapes that read an async value and invent an empty answer when it has
/// none. `.valueOrNull` is Riverpod 2; `.value` is the current spelling.
final _shapes = [
  LiteralKind(
    'value ?? empty literal',
    RegExp(r'\.value\s*\?\?\s*(const\s*)?[\[{<]'),
  ),
  LiteralKind('valueOrNull ??', RegExp(r'\.valueOrNull\s*\?\?')),
  LiteralKind(
    'maybeWhen orElse empty',
    RegExp(r'\.maybeWhen\([^;]*?orElse:\s*\(\)\s*=>\s*(const\s*)?[\[{<]'),
  ),
];

/// The ceiling per area, as measured on 11 Nov 2026 (it only falls).
const _ceilings = <String, int>{
  'lib/features/money': 0,
  'lib/features/me': 14,
  'lib/features/reservations': 28,
};

int _count(String area) {
  final files = filesUnder([area]).where(
    (f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'),
  );
  var n = 0;
  for (final f in files) {
    for (final line in codeLines(f)) {
      if (line.contains('empty-ok:')) continue;
      for (final k in _shapes) {
        if (k.pattern.hasMatch(line)) n++;
      }
    }
  }
  return n;
}

void main() {
  for (final entry in _ceilings.entries) {
    test('${entry.key}: invented empty answers only fall (#3680)', () {
      final actual = _count(entry.key);
      expect(
        actual,
        entry.value,
        reason:
            '${entry.key}: $actual uses of `.value ?? <empty>` on an async '
            'read (ceiling ${entry.value}). A failed read must reach the '
            'screen as a failure with Try again, never as an empty list: use '
            'AsyncReadBody / ReadFailureBanner, or mark the line '
            '`// empty-ok: <why an empty answer is right here>`. '
            'A fall must lower the ceiling in this file.',
      );
    });
  }

  test('the shapes can fail: the planted lines are found', () {
    const planted = [
      'final x = ref.watch(p).value ?? const [];',
      'final y = ref.watch(p).value ?? <String>[];',
      'final z = ref.watch(p).valueOrNull ?? 0;',
      'a.maybeWhen(data: (d) => d, orElse: () => const []);',
    ];
    for (final line in planted) {
      expect(_shapes.any((k) => k.pattern.hasMatch(line)), isTrue, reason: line);
    }
    expect(
      _shapes.any((k) => k.pattern.hasMatch('final a = v.value ?? 0;')),
      isFalse,
      reason: 'a scalar default is a different question',
    );
  });
}
