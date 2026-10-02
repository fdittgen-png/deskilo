// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — exact money: amounts in integer minor units of a currency
// with a reviewed exponent, sums that refuse to mix currencies or to
// overflow, splits that always add back up, and conversions that need
// an approved rate. Every expected value below is written out by hand.
import 'dart:convert';

import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:flutter_test/flutter_test.dart';

AccountingAmount eur(String major) => AccountingAmount.parse('EUR', major);

Matcher refused(AccountingError error) =>
    throwsA(isA<AccountingException>().having((e) => e.error, 'error', error));

FxRate rate(String base, String quote, String value) => FxRate(
  base: base,
  quote: quote,
  rate: ExactDecimal.parse(value),
  source: 'accountant',
  date: DateTime.utc(2026, 9, 30),
  version: '1',
);

void main() {
  group('amounts', () {
    test('100.00 net + 20.00 tax = 120.00 gross', () {
      expect((eur('100.00') + eur('20.00')).minor, 12000);
      expect((eur('100.00') + eur('20.00')).toDecimalString(), '120.00');
    });

    test('zero, two and three decimals keep their own grain', () {
      expect(AccountingAmount.parse('JPY', '5000').minor, 5000);
      expect(AccountingAmount.parse('JPY', '5000').toDecimalString(), '5000');
      expect(AccountingAmount.parse('KWD', '1.250').minor, 1250);
      expect(AccountingAmount.parse('KWD', '1.25').toDecimalString(), '1.250');
      expect(AccountingAmount.parse('EUR', '-0.05').toDecimalString(), '-0.05');
    });

    test('more digits than the currency carries are refused, not rounded', () {
      expect(
        () => AccountingAmount.parse('EUR', '1.005'),
        refused(AccountingError.excessPrecision),
      );
      expect(
        () => AccountingAmount.parse('JPY', '1.5'),
        refused(AccountingError.excessPrecision),
      );
    });

    test('only plain decimals parse', () {
      for (final bad in ['', ' ', '0x10', '1e3', '1,50', 'NaN', '+1', '1.']) {
        expect(
          () => AccountingAmount.parse('EUR', bad),
          refused(AccountingError.malformedDecimal),
          reason: '"$bad"',
        );
      }
    });

    test('an unreviewed currency is refused, never read as two decimals', () {
      expect(
        () => AccountingAmount('XYZ', 100),
        refused(AccountingError.unsupportedCurrency),
      );
      expect(
        () => AccountingAmount.parse('', '1.00'),
        refused(AccountingError.unsupportedCurrency),
      );
    });

    test('sums never mix currencies', () {
      expect(
        () => eur('1.00') + AccountingAmount.parse('USD', '1.00'),
        refused(AccountingError.currencyMismatch),
      );
    });

    test('values past 2^53 - 1 are refused, also when a sum gets there', () {
      expect(AccountingAmount('EUR', 9007199254740991).minor, 9007199254740991);
      expect(
        () => AccountingAmount('EUR', 9007199254740992),
        refused(AccountingError.outOfRange),
      );
      expect(
        () => AccountingAmount.parse('EUR', '90071992547409.93'),
        refused(AccountingError.outOfRange),
      );
      expect(
        () =>
            AccountingAmount('EUR', 9007199254740991) +
            AccountingAmount('EUR', 1),
        refused(AccountingError.outOfRange),
      );
    });

    test('the wire form carries the minor units as a string', () {
      final big = AccountingAmount('EUR', 9007199254740991);
      final wire = jsonEncode(big.toJson());
      expect(
        wire,
        '{"currency":"EUR","exponent":2,"minor":"9007199254740991"}',
      );
      expect(
        AccountingAmount.fromJson(jsonDecode(wire) as Map<String, Object?>),
        big,
      );
      expect(
        () => AccountingAmount.fromJson({
          'currency': 'JPY',
          'exponent': 2,
          'minor': '100',
        }),
        refused(AccountingError.unsupportedCurrency),
      );
    });
  });

  group('allocation', () {
    test('100.00 in three is 33.34 + 33.33 + 33.33', () {
      expect(eur('100.00').allocate([1, 1, 1]).map((a) => a.minor), [
        3334,
        3333,
        3333,
      ]);
    });

    test('a weighted split adds back to the whole', () {
      final parts = eur('10.00').allocate([1, 2, 3]);
      expect(parts.map((a) => a.minor), [167, 333, 500]);
      expect(parts.fold(0, (n, a) => n + a.minor), 1000);
    });

    test('the remainder goes to the largest fractional share', () {
      // 1.00 over 1:2 is 0.333… and 0.666…: the cent goes to the second.
      expect(eur('1.00').allocate([1, 2]).map((a) => a.minor), [33, 67]);
    });

    test('a reversal splits as the exact mirror', () {
      final forward = eur('100.00').allocate([1, 1, 1]);
      final back = eur('-100.00').allocate([1, 1, 1]);
      for (var i = 0; i < 3; i++) {
        expect(back[i].minor, -forward[i].minor);
      }
    });
  });

  group('exchange', () {
    test('USD 120.00 at an approved 0.90 is EUR 108.00', () {
      final usd = AccountingAmount.parse('USD', '120.00');
      expect(
        convert(usd, rate('USD', 'EUR', '0.90'), RoundingPolicy.halfUp),
        eur('108.00'),
      );
    });

    test('settled at 0.92: EUR 110.40, with EUR 2.40 as exchange gain', () {
      final usd = AccountingAmount.parse('USD', '120.00');
      final r = settleForeign(
        usd,
        bookedAt: rate('USD', 'EUR', '0.90'),
        settledAt: rate('USD', 'EUR', '0.92'),
        policy: RoundingPolicy.halfUp,
      );
      expect(r.booked, eur('108.00'));
      expect(r.settled, eur('110.40'));
      expect(r.fxDifference, eur('2.40'));
    });

    test('no rate, or a rate for another pair, blocks', () {
      final usd = AccountingAmount.parse('USD', '120.00');
      expect(
        () => convert(usd, null, RoundingPolicy.halfUp),
        refused(AccountingError.missingRate),
      );
      expect(
        () => convert(usd, rate('GBP', 'EUR', '1.17'), RoundingPolicy.halfUp),
        refused(AccountingError.missingRate),
      );
    });

    test('exponents differ across a conversion: JPY to EUR and back', () {
      final yen = AccountingAmount.parse('JPY', '1000');
      expect(
        convert(yen, rate('JPY', 'EUR', '0.0062'), RoundingPolicy.halfUp),
        eur('6.20'),
      );
      expect(
        convert(
          eur('6.20'),
          rate('EUR', 'JPY', '161.29'),
          RoundingPolicy.halfUp,
        ),
        AccountingAmount.parse('JPY', '1000'),
      );
    });

    test('the policy decides a half: 0.125 → 0.13 up, 0.12 even', () {
      final half = AccountingAmount.parse('EUR', '0.25');
      final r = rate('EUR', 'EUR', '0.5');
      expect(convert(half, r, RoundingPolicy.halfUp).minor, 13);
      expect(convert(half, r, RoundingPolicy.halfEven).minor, 12);
    });
  });
}
