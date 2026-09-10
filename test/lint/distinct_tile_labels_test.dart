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

/// Pairs that appear on ONE card and must not both claim the same verb
/// while counting in different units (#1058). The statement said
/// "5 of 11 days used" directly above "10 of 22 half-days used": the same
/// quantity, written twice, and a reader has to work out that 5 = 10/2
/// before the card makes sense.
const List<(String, String, String)> _sameVerbDifferentUnit = [
  ('entitlementDaysUsed', 'billEntitlement', 'used'),
];

Map<String, dynamic> _arb(String locale) =>
    json.decode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

/// The message with its placeholders removed. `{used}` contains the word
/// "used", so a naive contains() sees the verb in every message that takes
/// that argument, including the ones that never say it.
String _verbOf(String s) =>
    s.replaceAll(RegExp(r'{[^}]*}'), ' ').toLowerCase();

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

  test('one card never counts two units under the same verb', () {
    // English is the canonical locale and the only one whose verb we can
    // assert on; the others follow it structurally, and the widget test
    // covers what a reader actually sees.
    final arb = _arb('en');
    final muddles = <String>[];
    for (final (a, b, verb) in _sameVerbDifferentUnit) {
      final va = _verbOf(arb[a] as String);
      final vb = _verbOf(arb[b] as String);
      final aHasHalf = va.contains('half-day');
      final bHasHalf = vb.contains('half-day');
      if (aHasHalf == bHasHalf) continue; // same unit — no confusion
      if (va.contains(verb) && vb.contains(verb)) {
        muddles.add('$a and $b both say "$verb" but count in '
            'different units:\n    $a: ${arb[a]}\n    $b: ${arb[b]}');
      }
    }
    expect(
      muddles,
      isEmpty,
      reason: 'On one card, a reader must not have to convert between '
          'units to see that two lines say the same thing:\n'
          '${muddles.join('\n')}',
    );
  });
}
