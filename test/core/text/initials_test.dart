// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3654 -- initials on grapheme clusters; names sort the way a reader expects.
import 'package:deskilo/core/text/collation.dart';
import 'package:deskilo/core/text/initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the first whole character, never half of one', () {
    expect(initialOf('Émile'), 'É');
    expect(initialOf('émile'), 'É', reason: 'E + combining accent');
    expect(initialOf('Åsa'), 'Å');
    expect(initialOf('Ørjan'), 'Ø');
    expect(initialOf('李雷'), '李');
    expect(initialOf('😀 Smile'), '😀');
    expect(initialOf('🇫🇷 France'), '🇫🇷');
    expect(initialOf('  '), '?');
  });

  test('two initials from the first two words', () {
    expect(initialsOf('élodie faure'), 'ÉF');
    expect(initialsOf('Zoë van der Berg'), 'ZV');
    expect(initialsOf('李雷 韩梅梅'), '李韩');
    expect(initialsOf('Bob'), 'B');
    expect(initialsOf(''), '?');
  });

  test('names sort with their accents beside the plain letter', () {
    final names = ['Zoë', 'Émile', 'Åsa', 'Ørjan', 'Zoe', 'Adam']
      ..sort(compareNames);
    expect(names.first, 'Adam');
    expect(names.indexOf('Émile'), lessThan(names.indexOf('Zoe')));
    expect(names.indexOf('Åsa'), lessThan(names.indexOf('Zoe')));
  });
}
