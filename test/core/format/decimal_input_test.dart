// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3487 — one reader of a typed number: the table of what each locale reads.
import 'package:deskilo/core/format/cents.dart';
import 'package:deskilo/core/format/decimal_input.dart';
import 'package:deskilo/core/i18n/workspace_currency.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantityProblem;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The inputs every locale reads alike.
  const common = <String, num?>{
    '0,5': 0.5,
    '0.5': 0.5,
    '1.234,56': 1234.56,
    '1,234.56': 1234.56,
    '1 234,56': 1234.56,
    '1 234,56': 1234.56,
    "1'234.56": 1234.56,
    '1’234.56': 1234.56,
    '1.234.567': 1234567,
    '-3': -3,
    '−3': -3,
    'abc': null,
    '': null,
    '   ': null,
    '1.2.3': null,
    '1,23,4': null,
    '1..2': null,
    '1.234.56': null,
    '--3': null,
  };

  // What a single separator followed by three digits means, by locale.
  const single = <String, Map<String, num>>{
    'de_DE': {'1.234': 1234, '1,234': 1.234},
    'fr_FR': {'1.234': 1.234, '1,234': 1.234},
    'de_CH': {'1.234': 1.234, '1,234': 1.234},
    'en_GB': {'1.234': 1.234, '1,234': 1234},
  };

  for (final locale in single.keys) {
    test('$locale reads the table', () {
      for (final MapEntry(:key, :value) in common.entries) {
        expect(parseDecimalInput(key, locale: locale), value, reason: '"$key"');
      }
      for (final MapEntry(:key, :value) in single[locale]!.entries) {
        expect(parseDecimalInput(key, locale: locale), value, reason: '"$key"');
      }
    });
  }

  test('a rate, a weight or a quantity: one separator, always decimal', () {
    for (final locale in single.keys) {
      expect(parseDecimalInput('9,975', locale: locale, grouping: false), 9.975);
      expect(parseDecimalInput('9.975', locale: locale, grouping: false), 9.975);
      expect(parseDecimalInput('0,5', locale: locale, grouping: false), 0.5);
      expect(parseDecimalInput('1.234,5', locale: locale, grouping: false), isNull);
      expect(parseDecimalInput('1 234', locale: locale, grouping: false), isNull);
    }
  });

  test('a minus is refused where it is not allowed', () {
    expect(parseDecimalInput('-3', allowNegative: false), isNull);
  });

  test('an unknown locale reads with English symbols', () {
    expect(parseDecimalInput('1,234', locale: 'xx_YY'), 1234);
  });

  group('amounts in minor units', () {
    tearDown(WorkspaceCurrency.reset);

    test('blank is free, negative or malformed is refused', () {
      expect(parseMinorInput('', locale: 'en_US'), 0);
      expect(parseMinorInput('-1', locale: 'en_US'), isNull);
      expect(parseMinorInput('12x', locale: 'en_US'), isNull);
    });

    test('a grouped amount in the member locale', () {
      expect(parseMinorInput('1.234,56', locale: 'de_DE'), 123456);
      expect(parseMinorInput('1 234,56', locale: 'fr_FR'), 123456);
      expect(parseMinorInput("1'234.56", locale: 'de_CH'), 123456);
      expect(parseMinorInput('1,234.56', locale: 'en_GB'), 123456);
      expect(parseMinorInput('1.234', locale: 'de_DE'), 123400);
    });

    test('a three-digit currency keeps a single separator decimal', () {
      WorkspaceCurrency.install('KWD');
      expect(parseMinorInput('1.234', locale: 'de_DE'), 1234);
      expect(parseMinorInput('1,234', locale: 'en_GB'), 1234);
    });
  });

  group('a quantity typed by a member (#4161)', () {
    String? text(String raw, String locale) =>
        exactQuantityFromInput(raw, locale: locale).value?.text;

    test('0,5 and 0.5 are the same exact quantity in every locale', () {
      for (final locale in ['fr_FR', 'de_DE', 'es_ES', 'it_IT', 'en_GB']) {
        expect(text('0,5', locale), '0.5', reason: locale);
        expect(text('0.5', locale), '0.5', reason: locale);
      }
    });

    test('grouping is read by the locale, digits are kept exactly', () {
      expect(text('1 234,5', 'fr_FR'), '1234.5');
      expect(text('1.234,5', 'de_DE'), '1234.5');
      expect(text('0,000001', 'fr_FR'), '0.000001');
      expect(text('.5', 'en_GB'), '0.5');
      expect(text('5.', 'en_GB'), '5');
    });

    test('too many decimals and too large are refused, never rounded', () {
      expect(exactQuantityFromInput('0,0000001', locale: 'fr_FR').problem, ExactQuantityProblem.tooManyDecimals);
      expect(exactQuantityFromInput('1 000 000 000 000', locale: 'fr_FR').problem, ExactQuantityProblem.outOfRange);
    });

    test('what is no number, and a minus where none is allowed, is malformed', () {
      for (final raw in ['', 'abc', '1e3', '-1']) {
        expect(exactQuantityFromInput(raw, locale: 'fr_FR').problem, ExactQuantityProblem.malformed, reason: raw);
      }
      expect(text('-1', 'fr_FR'), isNull);
    });

    test('the existing reader still gives the same numbers', () {
      expect(parseDecimalInput('0,5', locale: 'fr_FR'), 0.5);
      expect(parseDecimalInput('-1 234,5', locale: 'fr_FR'), -1234.5);
    });
  });

  // #4425 -- the put-away rate is sent as typed with either separator, ungrouped and without a locale; the
  // negotiation's amounts reach parseMinor untouched, which reads the grouping of the member's format.
  group('the input seam behind the put-away rate and the negotiation amounts', () {
    test('a rate typed with a comma or a dot is the same dot text, and a grouped rate is none', () {
      expect(decimalTextFromInput('1,0856', grouping: false), '1.0856');
      expect(decimalTextFromInput('1.0856', grouping: false), '1.0856');
      expect(decimalTextFromInput('1.234,5', grouping: false), isNull);
    });

    test('an amount reads the grouping of its format, never a comma turned into a dot', () {
      expect(parseMinorInput('1.234,50', locale: 'de_DE'), 123450);
      expect(parseMinorInput('1,234.50', locale: 'en_US'), 123450);
      expect(parseMinorInput('12,5', locale: 'de_DE'), 1250);
    });
  });
}
