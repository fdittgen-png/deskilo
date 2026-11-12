// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3653 — a first capital is taken by the locale's rules on the first
// user-perceived character, never the first code unit.
import 'package:deskilo/core/i18n/capitalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a month, a city and a label', () {
    expect(capitalizeFirst('juillet', locale: 'fr_FR'), 'Juillet');
    expect(capitalizeFirst('märz', locale: 'de_DE'), 'März');
    expect(capitalizeFirst('émile', locale: 'fr'), 'Émile');
  });

  test('the Turkish dotted capital, only in Turkish and Azerbaijani', () {
    expect(capitalizeFirst('istanbul', locale: 'tr_TR'), 'İstanbul');
    expect(capitalizeFirst('istanbul', locale: 'az'), 'İstanbul');
    expect(capitalizeFirst('istanbul', locale: 'en_GB'), 'Istanbul');
    expect(capitalizeFirst('istanbul'), 'Istanbul');
  });

  test('a first letter of two code units stays whole', () {
    // U+10428 DESERET SMALL LETTER LONG I (two UTF-16 code units).
    expect(capitalizeFirst('\u{10428}x'), '\u{10400}x');
  });

  test('nothing in, nothing out', () {
    expect(capitalizeFirst(''), '');
  });
}
