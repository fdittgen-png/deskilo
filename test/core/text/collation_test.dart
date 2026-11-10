// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3488 -- names sort by their folded form, then by the raw strings.
import 'package:deskilo/core/text/collation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accented initials sit beside their plain letter, case ignored', () {
    final names = ['Zoé', 'Émile', 'emil', 'Über', 'Uber', 'Ñandú', 'Nadal']
      ..sort(compareNames);
    // `emil` folds before `emile`; `Uber`/`Über` fold equal and fall back to
    // the raw strings, so the order is total.
    expect(names, ['emil', 'Émile', 'Nadal', 'Ñandú', 'Uber', 'Über', 'Zoé']);
  });

  test('the code-point order this replaces put accents after Z', () {
    expect('Émile'.compareTo('Zoé'), greaterThan(0));
    expect(compareNames('Émile', 'Zoé'), lessThan(0));
    expect(compareNames('Über', 'Zimmer'), greaterThan(0));
    expect(compareNames('Ñandú', 'Zapata'), lessThan(0));
  });

  test('ß, œ and æ fold to their letter pairs; equal names compare equal', () {
    expect(compareNames('Straße', 'Strasse'), isNonZero);
    expect(compareNames('Strasse', 'Straße'), -compareNames('Straße', 'Strasse'));
    expect(compareNames('Œuvre', 'Oeuvre'), isNonZero);
    expect(compareNames('Œuvre', 'Oez'), lessThan(0));
    expect(compareNames('Anna', 'Anna'), 0);
    expect(compareNames('anna', 'Anna'), isNonZero);
  });
}
