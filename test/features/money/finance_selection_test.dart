// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (1b) — a selection is of one business in one currency, only of
// invoices a payment may name now, and splits by month, oldest first, each
// month with what its invoices still owe.
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/finance_selection.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_request_ids.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceInvoice _invoice(
  String id, {
  String ws = 'ws-a',
  String currency = 'CHF',
  String? period = '2026-10',
  bool payable = true,
  int due = 1000,
  DateTime? issued,
}) => FinanceInvoice(
  id: id,
  workspaceId: ws,
  workspaceName: ws,
  number: 'N-$id',
  issuedAt: issued ?? DateTime.utc(2026, 11),
  totalCents: due,
  paidCents: 0,
  currency: currency,
  state: FinanceState.open,
  stillDueCents: due,
  period: period,
  payable: payable,
);

void main() {
  test('only an invoice a payment may name now, with its month known', () {
    expect(FinanceSelection.selectable(_invoice('a')), isTrue);
    expect(FinanceSelection.selectable(_invoice('a', payable: false)), isFalse);
    expect(FinanceSelection.selectable(_invoice('a', period: null)), isFalse);
  });

  test('one business and one currency: the first invoice decides', () {
    var s = FinanceSelection.none.toggled(_invoice('a'));
    expect(s.accepts(_invoice('b')), isTrue);
    expect(
      s.accepts(_invoice('c', ws: 'ws-b')),
      isFalse,
      reason: 'another business',
    );
    expect(
      s.accepts(_invoice('d', currency: 'EUR')),
      isFalse,
      reason: 'another currency',
    );
    s = s.toggled(_invoice('c', ws: 'ws-b'));
    expect(s.count, 1, reason: 'an invoice it does not accept changes nothing');
    s = s.toggled(_invoice('a'));
    expect(s.isEmpty, isTrue, reason: 'choosing it again removes it');
  });

  test('months, oldest first, each with what its invoices still owe', () {
    final s = FinanceSelection([
      _invoice(
        'n2',
        period: '2026-11',
        due: 2900,
        issued: DateTime.utc(2026, 12, 2),
      ),
      _invoice('o1', due: 12000),
      _invoice(
        'n1',
        period: '2026-11',
        due: 3000,
        issued: DateTime.utc(2026, 12),
      ),
    ]);
    expect(s.cents, 17900);
    expect(
      [
        for (final m in s.months)
          '${m.period} ${m.cents} ${m.invoices.map((i) => i.id).join(',')}',
      ],
      ['2026-10 12000 o1', '2026-11 5900 n1,n2'],
    );
  });

  test('a payment\'s request id belongs to its claim: another selection of the '
      'same amount is another payment', () {
    var n = 0;
    final ids = PaymentRequestIds(() => 'id-${++n}');
    String idOf(List<String> invoices) => ids.idFor(
      'ws',
      'm',
      PaymentProvider.stripe,
      PaymentRequestIds.forClaim('2026-10', invoices),
      1000,
    );
    final first = idOf(['b', 'a']);
    expect(
      idOf(['a', 'b']),
      first,
      reason: 'the same invoices in another order: the same payment',
    );
    expect(idOf(['c']), isNot(first));
  });

  test('the overview\'s answers about a payment are read', () {
    final i = FinanceInvoice.fromJson({
      'id': 'i',
      'workspace_id': 'w',
      'number': 'N-1',
      'issued_at': '2026-11-02T00:00:00Z',
      'currency': 'EUR',
      'state': 'open',
      'period': '2026-10',
      'in_payment': true,
      'claim_payment_id': 'p-1',
      'payment_received': false,
      'payable': false,
    });
    expect(
      (i.period, i.inPayment, i.claimPaymentId, i.paymentReceived, i.payable),
      ('2026-10', true, 'p-1', false, false),
    );
    final older = FinanceInvoice.fromJson({
      'id': 'i',
      'workspace_id': 'w',
      'issued_at': '2026-11-02T00:00:00Z',
      'currency': 'EUR',
    });
    expect(
      (older.period, older.inPayment, older.payable),
      (null, false, false),
      reason: 'a host that does not answer them offers nothing to select',
    );
  });
}
