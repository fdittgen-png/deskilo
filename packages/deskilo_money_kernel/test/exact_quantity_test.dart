// SPDX-License-Identifier: AGPL-3.0-or-later
// #4161 (A0) -- the bounded exact quantity: six decimals, canonical text,
// typed refusals, BigInt arithmetic with no binary float.
@TestOn('vm || js')
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';

const _max = '999999999999.999999';

void main() {
  group('canonical text', () {
    test('zero has one spelling, and a padded value shortens', () {
      expect(ExactQuantity.parse('0').text, '0');
      expect(ExactQuantity.parse('-0').text, '0');
      expect(ExactQuantity.parse('0.000000').text, '0');
      expect(ExactQuantity.parse('000.750000').text, '0.75');
      expect(ExactQuantity.parse('12').text, '12');
      expect(ExactQuantity.parse('12.500000').text, '12.5');
      expect(ExactQuantity.parse('-0.5').text, '-0.5');
    });

    test('the smallest and both range boundaries round-trip exactly', () {
      for (final t in ['0.000001', '-0.000001', _max, '-$_max']) {
        expect(ExactQuantity.parse(t).text, t);
      }
    });

    test('0.5 and 0.500000 are one value with one text', () {
      expect(ExactQuantity.parse('0.5'), ExactQuantity.parse('0.500000'));
      expect(ExactQuantity.parse('0.5').hashCode, ExactQuantity.parse('0.500000').hashCode);
    });
  });

  group('refusals are typed and never round', () {
    ExactQuantityProblem? problem(String t) => ExactQuantity.tryParse(t).problem;

    test('seven fractional digits, trailing zeros included', () {
      expect(problem('0.0000001'), ExactQuantityProblem.tooManyDecimals);
      expect(problem('0.7500000'), ExactQuantityProblem.tooManyDecimals);
      expect(problem('1.1234567'), ExactQuantityProblem.tooManyDecimals);
    });

    test('a magnitude beyond the bound', () {
      expect(problem('1000000000000'), ExactQuantityProblem.outOfRange);
      expect(problem('999999999999.9999991'), ExactQuantityProblem.tooManyDecimals);
      expect(problem('-1000000000000'), ExactQuantityProblem.outOfRange);
    });

    test('exponent, grouping, comma, spaces, signs and nothing', () {
      for (final t in ['1e3', '1,000', '0,5', ' 1', '1 ', '+1', '', '.5', '5.', '--1', '1.2.3', 'abc']) {
        expect(problem(t), ExactQuantityProblem.malformed, reason: "'$t'");
      }
    });

    test('parse throws the same problem', () {
      expect(
        () => ExactQuantity.parse('0.0000001'),
        throwsA(
          isA<ExactQuantityException>().having((e) => e.problem, 'problem', ExactQuantityProblem.tooManyDecimals),
        ),
      );
    });
  });

  group('exact arithmetic', () {
    test('three persisted 0.333333 sum to 0.999999, not 1', () {
      final third = ExactQuantity.parse('0.333333');
      expect((third + third + third).text, '0.999999');
    });

    test('no binary-float drift: 0.1 + 0.2 is 0.3', () {
      expect((ExactQuantity.parse('0.1') + ExactQuantity.parse('0.2')).text, '0.3');
    });

    test('the maximum survives arithmetic, a step beyond it throws', () {
      final max = ExactQuantity.parse(_max);
      expect((max - ExactQuantity.parse('0.000001')).text, '999999999999.999998');
      expect(
        () => max + ExactQuantity.parse('0.000001'),
        throwsA(isA<ExactQuantityException>().having((e) => e.problem, 'problem', ExactQuantityProblem.outOfRange)),
      );
      expect((max + -max).text, '0');
    });

    test('order, sign and the ExactDecimal view', () {
      final a = ExactQuantity.parse('1.5');
      final b = ExactQuantity.parse('1.500001');
      expect(a < b, isTrue);
      expect(b >= a, isTrue);
      expect(a.compareTo(b), isNegative);
      expect((-a).isNegative, isTrue);
      expect(ExactQuantity.zero.isZero, isTrue);
      expect(a.decimal == ExactDecimal.parse('1.5'), isTrue);
    });

    test('millionths carry the value without a float', () {
      expect(ExactQuantity.fromMicro(BigInt.from(333333)).text, '0.333333');
      expect(ExactQuantity.parse(_max).micro, BigInt.parse('999999999999999999'));
    });
  });

  group('#4393 scaled', () {
    ExactQuantityResult s(String q, int n, int d) => ExactQuantity.parse(q).scaled(n, d);
    test('an exact ratio is the exact value', () {
      for (final (q, n, d, want) in [
        ('1', 1, 1, '1'),
        ('2', 1, 4, '0.5'),
        ('3', 1, 3, '1'),
        ('1.5', 12, 1, '18'),
        ('0.000001', 1, 2, null),
        ('-6', 1, 4, '-1.5'),
        ('0', 7, 3, '0'),
      ]) {
        final r = s(q, n, d);
        expect(r.value?.text, want, reason: '$q * $n / $d');
      }
    });
    test('a ratio with no six-decimal value is a problem, never rounded', () {
      expect(s('1', 1, 3).problem, ExactQuantityProblem.notRepresentable);
      expect(s('0.000001', 1, 2).problem, ExactQuantityProblem.notRepresentable);
      expect(s('1', 1, 3).value, isNull);
    });
    test('rounded, as the stock ledger records it: half away from zero', () {
      expect(ExactQuantity.parse('1').scaled(1, 3, round: true).value?.text, '0.333333');
      expect(ExactQuantity.parse('2').scaled(1, 3, round: true).value?.text, '0.666667');
      expect(ExactQuantity.parse('-2').scaled(1, 3, round: true).value?.text, '-0.666667');
      expect(ExactQuantity.parse('0.000001').scaled(1, 2, round: true).value?.text, '0.000001');
      expect(ExactQuantity.parse('3').scaled(1, 3, round: true).value?.text, '1');
      expect(ExactQuantity.parse('-0.000003').scaled(1, 2, round: true).value?.text, '-0.000002');
    });
    test('a zero denominator and an overflow are problems', () {
      expect(s('1', 1, 0).problem, ExactQuantityProblem.zeroDenominator);
      expect(s('999999999999', 2, 1).problem, ExactQuantityProblem.outOfRange);
    });
  });
}
