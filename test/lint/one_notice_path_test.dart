// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4018 — one way to raise a notice: `AppSnack` (lib/core/ui/app_snack.dart).
// A notice raised through it keeps the shared rules (reading time, the
// announcement, the clearing when the context changes); a direct
// `ScaffoldMessenger` or `SnackBar(` skips them. A messenger of one's own
// is a `ScopedMessenger`, which the context change clears too. Counted per
// area; a ceiling only falls; invoicing and money are at zero.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

final _direct = RegExp(r'\bScaffoldMessenger(\.|\()|\bSnackBar\(');

/// The ceiling per area, measured on 15 Nov 2026 (it only falls).
const _ceilings = <String, int>{
  // The shell's own clearing of the app's messenger (snack_scope, the
  // entry into a business).
  'lib/app': 2,
  'lib/features/auth': 0,
  'lib/features/calendar': 0,
  'lib/features/directory': 4,
  'lib/features/editor': 0,
  'lib/features/events': 0,
  'lib/features/help': 0,
  'lib/features/kiosk': 0,
  'lib/features/mcp': 0,
  'lib/features/me': 6,
  'lib/features/members': 0,
  'lib/features/money': 0,
  'lib/features/plan': 0,
  'lib/features/profile': 0,
  'lib/features/reservations': 2,
  'lib/features/search': 0,
  'lib/features/task_recorder': 11,
  'lib/features/visits': 0,
  'lib/features/workspace': 21,
};

int _count(String area) {
  var n = 0;
  for (final f in filesUnder([area])) {
    if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
      continue;
    }
    for (final line in codeLines(f)) {
      if (line.trimLeft().startsWith('import ')) continue;
      if (_direct.hasMatch(line)) n++;
    }
  }
  return n;
}

void main() {
  test('every area of lib/features has a ceiling', () {
    final areas = {
      for (final f in filesUnder(['lib/features']))
        f.path.split(RegExp(r'[/\\]')).take(3).join('/'),
    };
    expect(
      areas.difference(_ceilings.keys.toSet()),
      isEmpty,
      reason: 'a new area starts at zero direct notices',
    );
  });

  for (final MapEntry(key: area, value: ceiling) in _ceilings.entries) {
    test('$area: direct notices only fall (#4018)', () {
      final actual = _count(area);
      expect(
        actual,
        ceiling,
        reason:
            '$area: $actual direct ScaffoldMessenger/SnackBar uses (ceiling '
            '$ceiling). Raise a notice with AppSnack; a messenger of its own '
            'is a ScopedMessenger. A fall lowers the ceiling in this file.',
      );
    });
  }

  test('the count can fail: a planted direct use is found', () {
    for (final line in [
      'ScaffoldMessenger.of(context).showSnackBar(x);',
      'messenger.showSnackBar(SnackBar(content: Text(t)));',
      'child: ScaffoldMessenger(child: page),',
    ]) {
      expect(_direct.hasMatch(line), isTrue, reason: line);
    }
    expect(_direct.hasMatch('child: ScopedMessenger(child: page),'), isFalse);
    expect(_direct.hasMatch('AppSnack.info(context, text);'), isFalse);
  });
}
