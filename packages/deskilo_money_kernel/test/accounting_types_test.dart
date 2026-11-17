// SPDX-License-Identifier: AGPL-3.0-or-later
// Accounting primitives preserve currency refusal, balanced FX rounding,
// exact expense shares and the owner's document-number preview without app state.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';


RepartitionMember _member(String id) =>
    (id: id, name: id, subscriptionPct: 100, usageDays: 1, customWeight: 1);

PostingLine _line(int debit, int credit) => PostingLine(
  role: debit == 0 ? BookRole.suppliers : BookRole.expenses,
  accountCode: debit == 0 ? '401' : '606',
  debit: AccountingAmount('CHF', debit),
  credit: AccountingAmount('CHF', credit),
);

void main() {
  test('euro formats refuse other and padded currency codes', () {
    expect(isEuroFormatCurrency('EUR'), isTrue);
    expect(isEuroFormatCurrency('eur'), isTrue);
    expect(isEuroFormatCurrency('CAD'), isFalse);
    expect(isEuroFormatCurrency(' EUR '), isFalse);
  });

  test('FX keeps originals and balances the rounding gap at the held rate', () {
    final source = Posting(
      journal: PostingJournal.purchases,
      date: DateTime.utc(2026, 3, 1),
      kind: PostingKind.supplierBill,
      documentId: 'bill-1',
      documentNumber: 'B-1',
      lines: [_line(1, 0), _line(1, 0), _line(1, 0), _line(0, 3)],
    );
    FxRate rate(String base) => FxRate(
      base: base,
      quote: 'EUR',
      rate: ExactDecimal.parse('0.5'),
      source: 'accountant',
      date: source.date,
      version: 'held-rate',
    );
    final result = postingAtRate(source, rate('CHF'));
    expect(result.balanced, isTrue);
    expect(result.lines.map((l) => l.debit.minor), [1, 1, 1, 0]);
    expect(result.lines.last.credit.minor, 3);
    expect(result.lines.map((l) => l.original?.minor), [1, 1, 1, 3]);
    expect(result.lines.every((l) => l.debit.currency == 'EUR'), isTrue);
    expect(result.documentId, 'bill-1');
    expect(source.lines.first.debit.currency, 'CHF');
    expect(
      () => postingAtRate(source, rate('USD')),
      throwsA(isA<AccountingException>()),
    );
  });

  test('expense shares keep every cent, tie order and reversal sign', () {
    final members = [_member('a'), _member('b'), _member('c')];
    List<int> split(int amount) => distributeExpense(
      amountCents: amount,
      members: members,
      method: RepartitionMethod.equal,
    ).map((s) => s.amountCents).toList();
    expect(split(10000), [3334, 3333, 3333]);
    expect(split(-10000), [-3334, -3333, -3333]);
    expect(split(0), isEmpty);
  });

  test('expense rows retain their member subject, status and system stamp', () {
    final row = ExpenseRepartition.fromJson({
      'id': 'split-1',
      'title': 'Shared bill',
      'amount_cents': -101,
      'method': 'equal',
      'period': '2026-03',
      'status': 'confirmed',
      'created_at': '2026-03-01T00:00:00Z',
      'company_id': 'issuer-a',
      'shares': [
        {
          'member_id': 'member-a',
          'member_name': 'A',
          'weight': 1,
          'amount_cents': -101,
        },
      ],
    });
    expect(row.isReversal, isTrue);
    expect(row.isPending, isFalse);
    expect(row.system.companyId, 'issuer-a');
    expect(row.shares.single.toJson(), {
      'member_id': 'member-a',
      'amount_cents': -101,
      'weight': 1,
    });
  });

  test(
    'number previews retain the stored pattern, inverse and reset refusal',
    () {
      final series = NumberSequence.fromDb({
        'journal': 'invoice',
        'prefix': 'INV-',
        'suffix': '-A',
        'date_part': 'year_month',
        'digits': 4,
        'reset': 'monthly',
        'next_value': 57,
        'period_key': '2026-03',
      });
      expect(series.format(57, DateTime(2026, 3, 1)), 'INV-2026-03-0057-A');
      expect(series.counterOf('INV-2026-03-0057-A'), 57);
      expect(series.counterOf('CN-2026-03-0057-A'), isNull);
      expect(series.stored, isTrue);
      expect(series.copyWith(), series);
      expect(
        series.copyWith(datePart: NumberDatePart.year).removesDateFrom(series),
        isTrue,
      );
      expect(
        NumberSequence.effectiveReset(NumberDatePart.year, NumberReset.monthly),
        NumberReset.yearly,
      );
      expect(
        NumberSequence.defaultsFor('member').format(7, DateTime(2026)),
        'M-0007',
      );
    },
  );
}
