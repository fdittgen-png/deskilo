// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A typed date and a typed amount, per format locale: what each reads as
// and what each refuses, with its reason. A refused input is never turned
// into another date or another amount (a rolled-over day, a dropped sign,
// a rounded decimal, a century guessed for a two-digit year).
import 'package:deskilo/core/format/amount_input.dart';
import 'package:deskilo/core/format/date_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _locales = ['de_DE', 'de_CH', 'fr_FR', 'en_GB', 'en_US'];

/// The 1 February 2030 and the 29 February 2028 as each locale types them,
/// with separators, and as eight digits.
const _typed = <String, List<String>>{
  'de_DE': ['1.2.2030', '01.02.2030', '01022030', '29.02.2028'],
  'de_CH': ['1.2.2030', '01.02.2030', '01022030', '29.02.2028'],
  'fr_FR': ['01/02/2030', '1/2/2030', '01022030', '29/02/2028'],
  'en_GB': ['01/02/2030', '1-2-2030', '01022030', '29/02/2028'],
  'en_US': ['2/1/2030', '02/01/2030', '02012030', '02/29/2028'],
};

const _impossible = <String, List<String>>{
  'de_DE': ['31.02.2030', '1.13.2030', '29.02.2027', '00.01.2030'],
  'de_CH': ['31.02.2030', '1.13.2030', '29.02.2027', '31022030'],
  'fr_FR': ['31/02/2030', '01/13/2030', '29/02/2027', '31042030'],
  'en_GB': ['31/02/2030', '01/13/2030', '29/02/2027', '00012030'],
  'en_US': ['02/31/2030', '13/01/2030', '02/29/2027', '13012030'],
};

void main() {
  setUpAll(initializeDateFormatting);

  group('a typed date', () {
    for (final locale in _locales) {
      group(locale, () {
        DateRead read(String raw) => readDateInput(raw, locale: locale);

        test('reads its own order, with separators or as eight digits', () {
          final [a, b, c, leap] = _typed[locale]!;
          for (final raw in [a, b, c]) {
            expect(read(raw), (
              date: DateTime(2030, 2),
              problem: null,
            ), reason: raw);
          }
          expect(read(leap).date, DateTime(2028, 2, 29));
        });

        test('refuses a date that does not exist, never rolls it over', () {
          for (final raw in _impossible[locale]!) {
            expect(read(raw), (
              date: null,
              problem: DateInputProblem.impossible,
            ), reason: raw);
          }
        });

        test('refuses a two-digit year, never guesses its century', () {
          for (final raw in ['1.2.30', '01/02/30', '010230']) {
            expect(
              read(raw).problem,
              DateInputProblem.twoDigitYear,
              reason: raw,
            );
          }
        });

        test('refuses what is not a date', () {
          for (final raw in [
            'abc',
            '1.2',
            '0102203',
            '010220300',
            '1..2.2030x',
            '12e3',
          ]) {
            expect(read(raw).problem, DateInputProblem.malformed, reason: raw);
          }
          expect(read('   '), (date: null, problem: null));
        });

        test('a date it writes back reads as the same calendar date', () {
          for (final date in [DateTime(2030, 2), DateTime(2026, 12, 31)]) {
            final text = formatDateInput(date, locale: locale);
            expect(read(text).date, date, reason: text);
          }
        });
      });
    }

    test('outside the allowed dates is refused', () {
      final first = DateTime(2026);
      final last = DateTime(2026, 12, 31);
      DateInputProblem? problem(String raw) =>
          readDateInput(raw, locale: 'de_DE', first: first, last: last).problem;
      expect(problem('31.12.2025'), DateInputProblem.outOfRange);
      expect(problem('01.01.2027'), DateInputProblem.outOfRange);
      expect(problem('01.01.2026'), isNull);
      expect(problem('31.12.2026'), isNull);
    });
  });

  group('a typed amount', () {
    AmountRead read(
      String raw,
      String locale, {
      String currency = 'EUR',
      bool allowNegative = false,
    }) => readAmountInput(
      raw,
      locale: locale,
      currency: currency,
      allowNegative: allowNegative,
    );

    const ok = <String, Map<String, int>>{
      'de_DE': {'1.234,56': 123456, '1234,56': 123456, '12': 1200, '0,5': 50},
      'de_CH': {"1'234.56": 123456, '1’234.56': 123456, '1234.5': 123450},
      'fr_FR': {
        '1 234,56': 123456,
        '1\u00a0234,56': 123456,
        '1\u202f234,56': 123456,
      },
      'en_GB': {'1,234.56': 123456, '1234.56': 123456, '1,234': 123400},
      'en_US': {'1234.56': 123456, '1,234.56': 123456, '.5': 50},
    };

    for (final locale in _locales) {
      group(locale, () {
        test('reads each separator of the locale', () {
          ok[locale]!.forEach((raw, minor) {
            expect(read(raw, locale), (
              minor: minor,
              problem: null,
            ), reason: raw);
          });
        });

        test('refuses an exponent and a doubled separator', () {
          for (final raw in [
            '12e3',
            '1E3',
            '12,,5',
            '12..5',
            '1.2.3,4,5',
            '12 EUR',
            '--5',
          ]) {
            expect(
              read(raw, locale).problem,
              AmountInputProblem.notANumber,
              reason: raw,
            );
          }
        });

        test('refuses a negative amount where none is allowed', () {
          expect(read('-5', locale).problem, AmountInputProblem.negative);
          expect(read('−5', locale).problem, AmountInputProblem.negative);
          expect(read('-5', locale, allowNegative: true).minor, -500);
        });

        test('refuses one decimal too many, never rounds it', () {
          final three = locale.startsWith('en') || locale == 'de_CH'
              ? '1.005'
              : '1,005';
          expect(
            read(three, locale).problem,
            AmountInputProblem.tooManyDecimals,
          );
        });

        test('JPY has no decimals: 1.5 is refused, 1500 is 1500', () {
          final half = locale.startsWith('en') || locale == 'de_CH'
              ? '1.5'
              : '1,5';
          expect(
            read(half, locale, currency: 'JPY').problem,
            AmountInputProblem.tooManyDecimals,
          );
          expect(read('1500', locale, currency: 'JPY').minor, 1500);
        });

        test('KWD has three decimals: 1.234 is 1234 minor units', () {
          final dinar = locale.startsWith('en') || locale == 'de_CH'
              ? '1.234'
              : '1,234';
          expect(read(dinar, locale, currency: 'KWD'), (
            minor: 1234,
            problem: null,
          ));
          final four = locale.startsWith('en') || locale == 'de_CH'
              ? '1.2345'
              : '1,2345';
          expect(
            read(four, locale, currency: 'KWD').problem,
            AmountInputProblem.tooManyDecimals,
          );
        });

        test('nothing typed is neither an amount nor a problem', () {
          expect(read('  ', locale), (minor: null, problem: null));
        });
      });
    }
  });

  group('a prefilled amount', () {
    test('is written in the reader\'s separator and read back as written', () {
      for (final locale in _locales) {
        for (final currency in ['EUR', 'CHF', 'JPY', 'KWD']) {
          for (final minor in [123400, 123456, 5, 0, -123456]) {
            final text = amountInputText(
              minor,
              currency: currency,
              locale: locale,
            );
            expect(
              readAmountInput(
                text,
                locale: locale,
                currency: currency,
                allowNegative: true,
              ),
              (minor: minor, problem: null),
              reason: '$locale $currency $minor -> "$text"',
            );
          }
        }
      }
    });

    test('in the separator a person of that locale types', () {
      String text(String locale, String currency, int minor) =>
          amountInputText(minor, currency: currency, locale: locale);
      expect(text('de_DE', 'EUR', 1250), '12,50');
      expect(text('fr_FR', 'EUR', 1250), '12,50');
      expect(text('en_GB', 'EUR', 1250), '12.50');
      expect(text('en_US', 'EUR', 1250), '12.50');
      expect(text('de_CH', 'CHF', 1250), '12.50');
      expect(text('de_DE', 'JPY', 1500), '1500');
      expect(text('de_DE', 'KWD', 1250), '1,250');
      expect(text('en_US', 'KWD', 1250), '1.250');
      expect(text('en_GB', 'EUR', 5), '0.05');
    });
  });
}
