// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3599 — what Me says I owe: one figure per currency, a credit taken off the
// invoices of the business that issued it and never another one's, a credit
// note never a debt of mine, and an invoice without a currency never read.
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/my_finances_screen.dart' show invoice;

final _past = DateTime(2020);
final _later = DateTime(2099);
final _now = DateTime(2026, 11, 10, 12);

void main() {
  test('a credit of one business never lowers what I owe another', () {
    final o = FinanceOverview(
      invoices: [
        invoice('a', ws: 'A', currency: 'CHF', total: 40000),
        invoice('b', ws: 'B', currency: 'CHF', total: -2000),
      ],
    );
    expect(o.owedByCurrency, {'CHF': 40000});
    expect(o.inMyFavourByCurrency, {'CHF': 2000});
    expect(o.payable.map((i) => i.id), ['a']);
  });

  test("a business's own credit lowers what I pay that business", () {
    final o = FinanceOverview(
      invoices: [
        invoice('a', ws: 'A', currency: 'CHF', total: 40000),
        invoice('c', ws: 'A', currency: 'CHF', total: -2000),
      ],
    );
    expect(o.owedByCurrency, {'CHF': 38000});
    expect(o.inMyFavourByCurrency, isEmpty);
  });

  test('a credit beyond what I owe its business is held for me', () {
    final o = FinanceOverview(
      invoices: [
        invoice('a', ws: 'A', total: 12000),
        invoice('c', ws: 'A', total: -15000),
        invoice('b', ws: 'B', total: 3000),
      ],
    );
    expect(o.owedByCurrency, {'EUR': 3000});
    expect(o.inMyFavourByCurrency, {'EUR': 3000});
  });

  test('a credit in another currency of the same business is no discount', () {
    final o = FinanceOverview(
      invoices: [
        invoice('a', ws: 'A', total: 12000),
        invoice('c', ws: 'A', currency: 'CHF', total: -4000),
      ],
    );
    expect(o.owedByCurrency, {'EUR': 12000});
    expect(o.inMyFavourByCurrency, {'CHF': 4000});
  });

  test('the figures come in the order of the currency codes', () {
    final o = FinanceOverview(
      invoices: [
        invoice('1', currency: 'USD', due: _past),
        invoice('2', due: _later),
        invoice('3', currency: 'CAD'),
      ],
    );
    expect(o.owedByCurrency.keys, ['CAD', 'EUR', 'USD']);
  });

  test('only the currency of a late invoice is late', () {
    final o = FinanceOverview(
      invoices: [
        invoice('1', currency: 'USD', due: _past),
        invoice('2', due: _later),
        invoice('3', currency: 'CHF', state: FinanceState.paid, due: _past),
      ],
    );
    expect(o.overdueCurrencies(_now), {'USD'});
  });

  test('a credit note is never late and never to pay', () {
    final credit = invoice('c', total: -2000, due: _past);
    expect(credit.overdueAt(_now), isFalse);
    final o = FinanceOverview(invoices: [credit]);
    expect(o.payable, isEmpty);
    expect(o.owedByCurrency, isEmpty);
    expect(o.overdueCurrencies(_now), isEmpty);
    expect(o.outstanding, [credit], reason: 'still an open document of mine');
  });

  group('an invoice of mine names its currency', () {
    Map<String, dynamic> row({Object? currency = 'CHF'}) => {
      'id': 'i1',
      'workspace_id': 'w1',
      'workspace_name': 'Studio',
      'number': '2026-0001',
      'issued_at': '2026-11-01T10:00:00Z',
      'total_cents': 12000,
      'paid_cents': 0,
      'state': 'open',
      'currency': ?currency,
    };

    test('read with it', () {
      expect(FinanceInvoice.fromJson(row()).currency, 'CHF');
    });

    test('without it the answer is not read: never another currency', () {
      expect(
        () => FinanceInvoice.fromJson(row(currency: null)),
        throwsA(anything),
      );
      expect(
        () => FinanceOverview.fromJson({
          'invoices': [row(currency: null)],
          'reminders': const <Object>[],
        }),
        throwsA(anything),
      );
    });
  });
}
