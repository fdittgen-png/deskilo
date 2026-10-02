// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — tax components as distinct facts: an exact rate (9.975, not
// 9.98), zero-rated / exempt / out of scope / reverse charge kept apart,
// an unclassified treatment that blocks, and purchase tax split into
// what may and may not be deducted. The Quebec figures are Revenu
// Québec's own two-step example on CAD 1000.00 (assumed taxable).
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/accounting_tax.dart';
import 'package:flutter_test/flutter_test.dart';

AccountingAmount cad(String major) => AccountingAmount.parse('CAD', major);
AccountingAmount eur(String major) => AccountingAmount.parse('EUR', major);

TaxComponent tax(
  AccountingAmount basis,
  TaxTreatment treatment, {
  String scheme = 'VAT',
  String authority = 'FR',
  String? rate,
}) => projectTax(
  basis: basis,
  scheme: scheme,
  authority: authority,
  treatment: treatment,
  ratePercent: rate,
  rateVersion: '2026-01-01',
  policy: RoundingPolicy.halfUp,
);

void main() {
  test('GST 5 % and QST 9.975 % on CAD 1000.00: 50.00 + 99.75 → 1149.75', () {
    final net = cad('1000.00');
    final gst = tax(
      net,
      TaxTreatment.taxed,
      scheme: 'GST',
      authority: 'CA',
      rate: '5',
    );
    final qst = tax(
      net,
      TaxTreatment.taxed,
      scheme: 'QST',
      authority: 'CA-QC',
      rate: '9.975',
    );
    expect(gst.amount, cad('50.00'));
    expect(qst.amount, cad('99.75'));
    expect(qst.ratePercent.toString(), '9.975');
    expect(net + gst.amount + qst.amount, cad('1149.75'));
  });

  test('mixed rates on one document stay separate components', () {
    final standard = tax(eur('100.00'), TaxTreatment.taxed, rate: '20');
    final reduced = tax(eur('50.00'), TaxTreatment.taxed, rate: '5.5');
    expect(standard.amount, eur('20.00'));
    expect(reduced.amount, eur('2.75'));
    expect(standard.reportKey, isNot(reduced.reportKey));
  });

  test('a credit note is the exact negative', () {
    expect(
      tax(eur('-100.00'), TaxTreatment.taxed, rate: '20').amount,
      eur('-20.00'),
    );
  });

  test(
    'zero-rated, exempt, out of scope and reverse charge are four facts',
    () {
      final keys = {
        for (final t in [
          TaxTreatment.zeroRated,
          TaxTreatment.exempt,
          TaxTreatment.outOfScope,
          TaxTreatment.reverseCharge,
        ])
          tax(eur('100.00'), t).reportKey,
      };
      expect(keys, hasLength(4));
      expect(
        tax(eur('100.00'), TaxTreatment.reverseCharge).amount,
        eur('0.00'),
      );
    },
  );

  test('two authorities at the same rate never share a report key', () {
    final a = tax(
      eur('100.00'),
      TaxTreatment.taxed,
      authority: 'FR',
      rate: '20',
    );
    final b = tax(
      eur('100.00'),
      TaxTreatment.taxed,
      authority: 'AT',
      rate: '20',
    );
    expect(a.reportKey, isNot(b.reportKey));
  });

  test('unclassified, rate-less or contradictory components block', () {
    expect(
      () => tax(eur('1.00'), TaxTreatment.unknown),
      throwsA(isA<TaxBlocker>()),
    );
    expect(
      () => tax(eur('1.00'), TaxTreatment.taxed),
      throwsA(isA<TaxBlocker>()),
    );
    expect(
      () => tax(eur('1.00'), TaxTreatment.taxed, rate: '0'),
      throwsA(isA<TaxBlocker>()),
    );
    expect(
      () => tax(eur('1.00'), TaxTreatment.exempt, rate: '20'),
      throwsA(isA<TaxBlocker>()),
    );
  });

  test('purchase tax: 50 % deductible of EUR 20.01 is 10.01 + 10.00', () {
    final split = splitDeductible(eur('20.01'), '50', RoundingPolicy.halfUp);
    expect(split.deductible, eur('10.01'));
    expect(split.nonDeductible, eur('10.00'));
    expect(
      () => splitDeductible(eur('1.00'), '101', RoundingPolicy.halfUp),
      throwsA(isA<TaxBlocker>()),
    );
  });

  test('the tax point: invoice date, or only once paid on the cash basis', () {
    final issued = DateTime.utc(2026, 9, 1);
    final paid = DateTime.utc(2026, 10, 15);
    expect(
      taxDueOn(TaxPointBasis.invoice, issuedOn: issued, paidOn: paid),
      issued,
    );
    expect(taxDueOn(TaxPointBasis.payment, issuedOn: issued), isNull);
    expect(
      taxDueOn(TaxPointBasis.payment, issuedOn: issued, paidOn: paid),
      paid,
    );
  });
}
