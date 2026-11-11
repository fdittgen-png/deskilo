// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- which payments no invoice has taken, and which invoices of the
// same customer and currency each could settle: the exact one first, then the
// oldest; a payment already consumed or spent inside a later invoice is not
// offered again.
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry _pay(
  String id, {
  int cents = 12000,
  LedgerKind kind = LedgerKind.credit,
  LedgerCategory category = LedgerCategory.payment,
  String member = 'anna',
  DateTime? on,
  String period = '2026-09',
}) => LedgerEntry(
  id: id,
  memberId: member,
  kind: kind,
  category: category,
  amountCents: cents,
  description: 'Transfer',
  period: period,
  createdAt: DateTime(2026, 9, 20),
  occurredOn: on,
);

Receivable _inv(
  String id, {
  int open = 12000,
  String currency = 'EUR',
  DateTime? issued,
  ReceivableStage stage = ReceivableStage.open,
}) => Receivable(
  invoiceId: id,
  customerId: 'anna',
  customerName: 'Anna Alder',
  number: 'INV-$id',
  currency: currency,
  totalMinor: open,
  openMinor: open,
  issuedOn: issued ?? DateTime(2026, 9),
  stage: stage,
);

void main() {
  group('unmatchedPaymentsOf', () {
    test('only credits that are a payment or an adjustment, newest first', () {
      final r = unmatchedPaymentsOf(
        memberId: 'anna',
        ledger: [
          _pay('old', on: DateTime(2026, 9, 3)),
          _pay('new', on: DateTime(2026, 9, 18)),
          _pay('charge', kind: LedgerKind.charge),
          _pay('other', category: LedgerCategory.service),
          _pay(
            'adjust',
            category: LedgerCategory.adjustment,
            on: DateTime(2026, 9, 10),
          ),
          _pay('ben', member: 'ben'),
        ],
        consumed: const {},
        invoices: const [],
      );
      expect(r.map((e) => e.id), ['new', 'adjust', 'old']);
    });

    test('a payment a match already consumed is not offered again', () {
      final r = unmatchedPaymentsOf(
        memberId: 'anna',
        ledger: [_pay('a'), _pay('b')],
        consumed: const {'a'},
        invoices: const [],
      );
      expect(r.map((e) => e.id), ['b']);
    });
  });

  group('candidatesFor', () {
    test('the invoice the payment settles exactly comes first, then the '
        'oldest', () {
      final c = candidatesFor(
        paymentMinor: 12000,
        currency: 'EUR',
        customerInvoices: [
          _inv('older', open: 5000, issued: DateTime(2026, 8)),
          _inv('exact', issued: DateTime(2026, 9, 5)),
          _inv('newer', open: 7000, issued: DateTime(2026, 9, 20)),
        ],
      );
      expect(c.map((e) => e.invoice.invoiceId), ['exact', 'older', 'newer']);
      expect(c.first.fit, MatchFit.exact);
      expect(c.last.fit, MatchFit.needsDecision);
    });

    test('only open invoices of the payment\'s own currency', () {
      final c = candidatesFor(
        paymentMinor: 9500,
        currency: 'EUR',
        customerInvoices: [
          _inv('chf', currency: 'CHF', open: 9500),
          _inv('paid', stage: ReceivableStage.paid, open: 9500),
          _inv('draft', stage: ReceivableStage.draft, open: 9500),
          _inv('ok', open: 9500),
        ],
      );
      expect(c.map((e) => e.invoice.invoiceId), ['ok']);
    });

    test('no invoice fits: no candidates, the payment stays as it is', () {
      expect(
        candidatesFor(
          paymentMinor: 100,
          currency: 'EUR',
          customerInvoices: const [],
        ),
        isEmpty,
      );
    });
  });
}
