// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3839 — the period built from readings of the open items (what the Demo
// does without the server, the server's own construction): each movement is
// what changed between two readings, so opening + movements = closing per
// currency; an item that appears on its own day is issued or received, one
// that shrinks is paid or allocated. And the server's answer is read whole.
import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:flutter_test/flutter_test.dart';

CustomerStatement _reading(DateTime at, {int due = 0, int left = 0}) =>
    CustomerStatement(
      memberId: 'm',
      asOf: at,
      currencies: statementCurrencies(
        lines: {
          if (due != 0)
            'EUR': [
              StatementLine(
                invoiceId: 'a',
                number: 'F-1',
                totalCents: 1000,
                stillDueCents: due,
                state: StatementLineState.open,
                issuedAt: DateTime(2026, 10, 3),
              ),
            ],
        },
        credits: {
          if (left != 0)
            'EUR': [
              StatementCredit(
                ledgerId: 'p',
                leftCents: left,
                category: 'payment',
                description: 'P',
                on: DateTime(2026, 10, 10),
              ),
            ],
        },
      ),
    );

void main() {
  test(
    'opening + movements = closing, each movement named for what it was',
    () {
      final period = statementPeriodOf(
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 31),
        opening: _reading(DateTime(2026, 10)),
        steps: [
          (
            DateTime(2026, 10, 3, 9),
            _reading(DateTime(2026, 10, 3), due: 1000),
          ),
          (
            DateTime(2026, 10, 10, 9),
            _reading(DateTime(2026, 10, 10), due: 1000, left: 1000),
          ),
          (DateTime(2026, 10, 15, 9), _reading(DateTime(2026, 10, 15))),
        ],
        closing: _reading(DateTime(2026, 11)),
      );
      final eur = period.currencies.single;
      expect(
        eur.openingCents +
            eur.movements.fold<int>(0, (s, m) => s + m.amountCents),
        eur.closingCents,
      );
      expect(
        [for (final m in eur.movements) '${m.what.wire} ${m.amountCents}'],
        ['invoice 1000', 'payment -1000', 'allocated 1000', 'paid -1000'],
      );
      // The invoice was paid on the 15th: its line keeps its own day (the
      // Demo has no allocation detail to name the payment's).
      expect(eur.movements[3].datedApart, isTrue);
    },
  );

  test('a period with no change has two equal balances and no movement', () {
    final period = statementPeriodOf(
      from: DateTime(2026, 10),
      to: DateTime(2026, 10, 31),
      opening: _reading(DateTime(2026, 10), due: 1000),
      steps: const [],
      closing: _reading(DateTime(2026, 11), due: 1000),
    );
    expect(period.currencies.single.movements, isEmpty);
    expect(
      period.currencies.single.openingCents,
      period.currencies.single.closingCents,
    );
  });

  test('the server\'s answer is read whole', () {
    final period = CustomerStatementPeriod.fromJson({
      'member_id': 'm',
      'from': '2026-10-01',
      'to': '2026-10-31',
      'history_from': '2026-10-12T08:00:00Z',
      'reconstructed_before': true,
      'currencies': [
        {
          'currency': 'EUR',
          'opening_cents': 0,
          'closing_cents': 0,
          'movements': [
            {
              'decided_on': '2026-10-30',
              'own_on': '2026-10-28',
              'label': 'F-1',
              'what': 'paid',
              'amount_cents': -1000,
            },
          ],
        },
      ],
    });
    expect(period.reconstructedBefore, isTrue);
    expect(
      period.currencies.single.movements.single.what,
      PeriodMovementWhat.paid,
    );
    expect(period.currencies.single.movements.single.datedApart, isTrue);
  });
}
