// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1150, #3484 — every number, amount, date and time a member reads goes
// through `AppFormat` (`ref.watch(appFormatProvider)`, or
// `appFormatOf(context)` without a ref): it is the one place that knows the
// member's format locale, clock (12/24h) and time-zone mode. A raw
// `DateFormat.Hm()` shows 14:30 to somebody who chose a 12-hour clock; a raw
// `.toLocal()` shows the device's zone to somebody who chose the workspace's.
//
// The raw calls left in presentation are COUNTED: each ceiling is the
// measure recorded before #3484's sweeps, and it only goes down. `Hm` and
// `jm` are at 0 since #1150.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// The recorded ceilings (#3484, measured on this branch's base).
const _ceilings = <String, int>{
  'DateFormat.': 141,
  'NumberFormat.': 31,
  'moneyFormat(': 93,
  '.toLocal()': 42,
  'WorkspaceTime.display': 8,
};

final _kinds = [
  LiteralKind('DateFormat.', RegExp(r'\bDateFormat\.')),
  LiteralKind('NumberFormat.', RegExp(r'\bNumberFormat\.')),
  LiteralKind('moneyFormat(', RegExp(r'\bmoneyFormat\(')),
  LiteralKind('.toLocal()', RegExp(r'\.toLocal\(\)')),
  LiteralKind('WorkspaceTime.display', RegExp(r'\bWorkspaceTime\.display\b')),
];

void main() {
  final presentation = filesUnder(['lib/features']).where(
    (f) =>
        f.path.contains('/presentation/') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart'),
  );

  test('presentation never formats a time with DateFormat.Hm or .jm', () {
    final counted = countLiterals(presentation, [
      LiteralKind('Hm/jm', RegExp(r'DateFormat\.(Hm|jm)\(')),
    ])['Hm/jm']!;
    expect(total(counted), 0,
        reason: 'use AppFormat.time() — ref.watch(appFormatProvider) or '
            'appFormatOf(context):\n${counted.keys.join('\n')}');
  });

  final counted = countLiterals(presentation, _kinds);
  for (final kind in _kinds) {
    test('raw "${kind.name}" calls in presentation only fall', () {
      final perFile = counted[kind.name]!;
      final ceiling = _ceilings[kind.name]!;
      expect(
        total(perFile),
        ceiling,
        reason: ratchetMessage(
          rule: 'format seam (#3484): format through AppFormat '
              '(ref.watch(appFormatProvider) or appFormatOf(context))',
          kind: kind.name,
          ceiling: ceiling,
          actual: total(perFile),
          perFile: perFile,
        ),
      );
    });
  }
}
