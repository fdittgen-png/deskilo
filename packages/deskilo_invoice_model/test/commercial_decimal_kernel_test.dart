// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4406 -- one exact decimal: the same table read by the kernel's ExactQuantity and by the
// commercial decimal gives the same canonical text, or the same problem under each one's name.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';

void main() {
  const table = <(String, String?, ExactQuantityProblem?, CommercialDecimalProblem?)>[
    ('1.5', '1.5', null, null),
    ('1.50', '1.5', null, null),
    ('10', '10', null, null),
    ('0.000001', '0.000001', null, null),
    ('-2.25', '-2.25', null, null),
    ('999999999999.999999', '999999999999.999999', null, null),
    ('1.1234567', null, ExactQuantityProblem.tooManyDecimals, CommercialDecimalProblem.excessPrecision),
    ('1.5000000', null, ExactQuantityProblem.tooManyDecimals, CommercialDecimalProblem.excessPrecision),
    ('1000000000000', null, ExactQuantityProblem.outOfRange, CommercialDecimalProblem.outOfRange),
    ('1,5', null, ExactQuantityProblem.malformed, CommercialDecimalProblem.malformed),
    ('+1', null, ExactQuantityProblem.malformed, CommercialDecimalProblem.malformed),
    ('1e3', null, ExactQuantityProblem.malformed, CommercialDecimalProblem.malformed),
    ('.5', null, ExactQuantityProblem.malformed, CommercialDecimalProblem.malformed),
    ('', null, ExactQuantityProblem.malformed, CommercialDecimalProblem.malformed),
  ];
  for (final (text, canonical, kernel, commercial) in table) {
    test("'$text' reads the same under both names", () {
      final q = ExactQuantity.tryParse(text);
      expect(q.value?.text, canonical);
      expect(q.problem, kernel);
      final c = parseCommercialDecimal(text, positive: false, allowNegative: true);
      expect(c.value?.text, canonical);
      expect(c.problem, commercial);
    });
  }
  test('the commercial rules stay its own: a quantity is positive, a price never negative', () {
    expect(parseCommercialDecimal('0').problem, CommercialDecimalProblem.notPositive);
    expect(parseCommercialDecimal('-1').problem, CommercialDecimalProblem.notPositive);
    expect(parseCommercialDecimal('-1', allowNegative: true).value?.text, '-1');
    expect(parseCommercialDecimal('0', positive: false).value?.text, '0');
    expect(parseCommercialDecimal('-1', positive: false).problem, CommercialDecimalProblem.notPositive);
  });
}
