// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the server's statement as the app reads it (customer_statement_v1's
// shape), and the per-currency totals the demo and the page build with:
// still due counts a credit note negative, the balance is still due −
// unapplied, and nothing is added across currencies.
import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the server answer: lines, parts, waiting parts and credits', () {
    final s = CustomerStatement.fromJson({
      'member_id': 'm',
      'as_of': '2026-10-01',
      'cutoff': '2026-10-01T22:00:00+00:00',
      'currencies': [
        {
          'currency': 'EUR',
          'still_due_cents': 7500,
          'unapplied_cents': 1000,
          'balance_cents': 6500,
          'invoices': [
            {
              'invoice_id': 'a',
              'number': 'ST-2C',
              'issued_at': '2026-09-02T08:00:00+00:00',
              'due_on': null,
              'total_cents': 3000,
              'still_due_cents': 3000,
              'state': 'awaiting_approval',
              'allocations': [
                {
                  'payment_id': 'q',
                  'on': '2026-09-25T08:00:00+00:00',
                  'amount_cents': 3000,
                  'awaiting_approval': true,
                },
              ],
            },
          ],
          'credits': [
            {
              'ledger_id': 'p',
              'category': 'payment',
              'description': 'P',
              'on': '2026-09-20T08:00:00+00:00',
              'left_cents': 1000,
            },
          ],
        },
      ],
    });
    final eur = s.currencies.single;
    expect(s.asOf, DateTime(2026, 10));
    expect(eur.balanceCents, 6500);
    final line = eur.lines.single;
    expect(line.state, StatementLineState.awaitingApproval);
    expect(line.dueOn, isNull);
    expect(line.allocations.single.awaitingApproval, isTrue);
    expect(eur.credits.single.leftCents, 1000);
  });

  test('an unknown state reads as open, never as paid', () {
    expect(StatementLineState.of('something_new'), StatementLineState.open);
  });

  test('totals per currency, a credit note negative, never across '
      'currencies', () {
    StatementLine line(String n, int due) => StatementLine(
      invoiceId: n,
      number: n,
      totalCents: due,
      stillDueCents: due,
      state: due < 0 ? StatementLineState.creditNote : StatementLineState.open,
    );
    final out = statementCurrencies(
      lines: {
        'KWD': [line('G', 12345)],
        'EUR': [line('A', 6000), line('D', -1500)],
      },
      credits: {
        'EUR': [const StatementCredit(ledgerId: 'p', leftCents: 1000)],
      },
    );
    expect(out.map((c) => c.currency), ['EUR', 'KWD']);
    expect(
      [
        out.first.stillDueCents,
        out.first.unappliedCents,
        out.first.balanceCents,
      ],
      [4500, 1000, 3500],
    );
    expect(out.last.balanceCents, 12345);
  });
}
