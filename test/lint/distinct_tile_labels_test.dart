// SPDX-License-Identifier: 0BSD
//
// #1057 — two rows of one list must not carry the same label.
//
// Settings showed "My badge" twice, one directly above the other: the
// badge itself, and the PIN that stands in for it when there is no
// reader. Two different keys (`myBadgeTitle`, `badgePinSectionTitle`)
// with the same value in all five locales, so no completeness check
// could see it — the ARBs were perfectly parallel and perfectly wrong.
//
// A pair listed here is a pair a person meets side by side. Add one
// whenever a screen grows two rows whose labels could drift together.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'de', 'es', 'fr', 'it'];

/// Keys that appear as adjacent rows, and so may never read alike.
const List<(String, String)> _mustDiffer = [
  ('myBadgeTitle', 'badgePinSectionTitle'),
];

Map<String, dynamic> _arb(String locale) =>
    json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('adjacent rows never carry the same label, in any locale', () {
    final clashes = <String>[];
    for (final locale in _locales) {
      final arb = _arb(locale);
      for (final (a, b) in _mustDiffer) {
        final va = arb[a];
        final vb = arb[b];
        expect(va, isNotNull, reason: '$a missing from $locale');
        expect(vb, isNotNull, reason: '$b missing from $locale');
        if (va == vb) clashes.add('$locale: $a and $b are both "$va"');
      }
    }
    expect(
      clashes,
      isEmpty,
      reason: 'These pairs sit next to each other on one screen and read '
          'identically, so nobody can tell which row does what:\n'
          '${clashes.join('\n')}',
    );
  });
}
