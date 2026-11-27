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
  // #3742 — a default object in place of an unread policy is the same lie:
  // `.value ?? Rules.defaults`, `.value ?? const Rules()`, `.asData?.value ??`.
  LiteralKind(
    'value ?? default object',
    RegExp(
      r'\.value\s*\?\?\s*(const\s+)?[A-Z]\w*'
      r'(\.(defaults|empty|none|initial)\b|\(\s*\))',
    ),
  ),
  LiteralKind('asData?.value ??', RegExp(r'\.asData\?\.value\s*\?\?')),
  // #4017 — a count read from a provider and shown as 0 when the read
  // failed: "nothing to decide" when the server did not answer.
  LiteralKind('read value ?? 0', RegExp(r'\)\.value\s*\?\?\s*0\b')),
  // #4489 — a guarded read whose fallback is an empty collection is the same
  // lie one layer down: "the units could not be read" becomes "there are no
  // units". The fallback says the failure, or the line gives its reason.
  LiteralKind(
    'guarded read fallback empty',
    RegExp(r'\bfallback:\s*\(\w*\)\s*=>\s*(const\s*)?(<[^>]*>\s*)?[\[{]'),
  ),
];

/// The ceiling per area, as measured on 11 Nov 2026 (it only falls).
/// #4017 — every area has one, measured on 15 Nov 2026 with `?? 0` counted.
const _ceilings = <String, int>{
  'lib/app': 6,
  'lib/core': 3,
  'lib/features/auth': 2,
  'lib/features/calendar': 10,
  'lib/features/directory': 19,
  'lib/features/editor': 0,
  'lib/features/events': 19,
  'lib/features/help': 1,
  'lib/features/kiosk': 5,
  'lib/features/mcp': 3,
  // #4489 counts a guarded read that falls back to an empty collection: the
  // till layout's services and tills.
  'lib/features/money': 2,
  // #3742 widened the shapes (a default object in place of an unread
  // value); #3749 removed the five places they found in Me.
  // #4017 counts `?? 0` on a read too: the unread notes' count is the 15th.
  'lib/features/me': 15,
  'lib/features/members': 19,
  'lib/features/plan': 2,
  'lib/features/profile': 7,
  'lib/features/reservations': 28,
  'lib/features/search': 0,
  // #4489: the places and items of the groups screen, an item's tags, the
  // reorder sheet's suppliers and the units of a line.
  'lib/features/stock': 5,
  'lib/features/task_recorder': 4,
  'lib/features/visits': 1,
  'lib/features/workspace': 53,
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
  test('every area of lib/ has a ceiling (#4017)', () {
    final areas = {
      'lib/app',
      'lib/core',
      for (final f in filesUnder(['lib/features']))
        f.path.split(RegExp(r'[/\\]')).take(3).join('/'),
    };
    expect(areas.difference(_ceilings.keys.toSet()), isEmpty,
        reason: 'a new area gets its ceiling here, at its measured count');
  });

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
      'final r = ref.watch(p).value ?? DunningRules.defaults;',
      'final r = ref.watch(p).value ?? const DunningRules();',
      'final r = ref.watch(p).asData?.value ?? x;',
      'int count(WidgetRef ref) => ref.watch(p).value ?? 0;',
      'fallback: (_) => const <WorkspaceUnit>[],',
      'fallback: (e) => [],',
      'fallback: (_) => const {},',
    ];
    for (final line in planted) {
      expect(_shapes.any((k) => k.pattern.hasMatch(line)), isTrue, reason: line);
    }
    expect(
      _shapes.any((k) => k.pattern.hasMatch('final a = v.value ?? 0;')),
      isFalse,
      reason: 'a scalar default is a different question',
    );
    expect(
      _shapes.any((k) => k.pattern.hasMatch('fallback: (e) => failureOf(e),')),
      isFalse,
      reason: 'a fallback that says the failure is the right one',
    );
    expect(
      _shapes.any((k) => k.pattern.hasMatch('final a = v.value ?? fallback;')),
      isFalse,
      reason: 'a named variable is the reader\'s own choice',
    );
  });
}
