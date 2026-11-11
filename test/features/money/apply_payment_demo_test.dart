// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 (part 2) -- one payment over several invoices, the parts the sheet
// works out and the Demo's answer: `apply_payment_to_invoices` as the SQL
// says it (0718): every part exact or under_accepted, all or nothing, each
// refusal in the server's words, and the junction keeps one row per part.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/assign_payment_plan.dart';
import 'package:deskilo/features/money/application/payment_candidates.dart';
import 'package:deskilo/features/money/application/receivables.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/screens/invoices.dart' show seededMoney;

Receivable _inv(String id, int open, {DateTime? due, DateTime? issued}) =>
    Receivable(
      invoiceId: id,
      customerId: 'anna',
      customerName: 'Anna',
      number: 'INV-$id',
      currency: 'EUR',
      totalMinor: open,
      openMinor: open,
      issuedOn: issued ?? DateTime(2026, 4),
      dueOn: due,
      stage: ReceivableStage.open,
    );

/// Two invoices of one member (a: 100.00, b: 50.00) and a payment of 200.00.
Future<(FakeMoneyRepository, String, String, String)> _fixture() async {
  final money = await seededMoney(matched: false);
  final first = money.invoices.single;
  final a = first.copyWith(id: 'inv-a', number: 'A', totalCents: 10000);
  final b = first.copyWith(id: 'inv-b', number: 'B', totalCents: 5000);
  money.invoices
    ..clear()
    ..addAll([a, b]);
  final payment = money.seedPayment(first.memberId, 20000);
  return (money, 'inv-a', 'inv-b', payment);
}

void main() {
  group('the Demo applies a payment to several invoices', () {
    test('exact parts: one match per part, the rest stays on the payment, '
        'the junction has one row per part', () async {
      final (money, a, b, payment) = await _fixture();
      final answer = await money.applyPaymentToInvoices(
        workspaceId: 'ws-1',
        paymentLedgerId: payment,
        allocations: [
          (invoiceId: a, amountCents: 10000),
          (invoiceId: b, amountCents: 5000),
        ],
      );
      expect(answer.invoices, 2);
      expect(answer.leftCents, 5000);
      expect(money.usedPaymentCents[payment], 15000);
      expect(money.invoiceMatchesStore[a]!.resolution, 'exact');
      expect(money.invoiceMatchesStore[b]!.resolution, 'exact');
      expect(money.invoiceMatchPaymentsStore[a]!.single.paidCents, 10000);
      expect(money.invoiceMatchPaymentsStore[b]!.single.paidCents, 5000);
    });

    test('a part below what is due is under_accepted and needs the note; '
        'nothing is kept when it is missing', () async {
      final (money, a, b, payment) = await _fixture();
      final parts = [
        (invoiceId: b, amountCents: 5000),
        (invoiceId: a, amountCents: 4000),
      ];
      await expectLater(
        money.applyPaymentToInvoices(
          workspaceId: 'ws-1',
          paymentLedgerId: payment,
          allocations: parts,
        ),
        throwsA(
          isA<StateError>().having(
            PaymentRefusal.of,
            'reason',
            PaymentRefusal.noteRequired,
          ),
        ),
      );
      expect(money.invoiceMatchesStore, isEmpty, reason: 'all or nothing');
      expect(money.usedPaymentCents[payment], isNull);
      expect(money.invoiceMatchPaymentsStore, isEmpty);

      await money.applyPaymentToInvoices(
        workspaceId: 'ws-1',
        paymentLedgerId: payment,
        allocations: parts,
        note: 'Partly paid',
      );
      expect(money.invoiceMatchesStore[a]!.resolution, 'under_accepted');
      expect(money.invoiceMatchesStore[b]!.resolution, 'exact');
      expect(money.usedPaymentCents[payment], 9000);
    });

    test(
      'each refusal is in the words of the server and keeps nothing',
      () async {
        final (money, a, b, payment) = await _fixture();
        Future<PaymentRefusal> refused(
          List<PaymentAllocation> parts, {
          String id = '',
        }) async {
          try {
            await money.applyPaymentToInvoices(
              workspaceId: 'ws-1',
              paymentLedgerId: id.isEmpty ? payment : id,
              allocations: parts,
            );
          } on Object catch (e) {
            expect(money.invoiceMatchesStore, isEmpty);
            return PaymentRefusal.of(e);
          }
          fail('the call was not refused');
        }

        expect(await refused([]), PaymentRefusal.business);
        expect(
          await refused([(invoiceId: a, amountCents: 100)], id: 'nope'),
          PaymentRefusal.business,
        );
        expect(
          await refused([
            (invoiceId: a, amountCents: 100),
            (invoiceId: a, amountCents: 100),
          ]),
          PaymentRefusal.duplicate,
        );
        expect(
          await refused([(invoiceId: a, amountCents: 0)]),
          PaymentRefusal.partBeyondInvoice,
        );
        expect(
          await refused([(invoiceId: 'other', amountCents: 100)]),
          PaymentRefusal.payer,
        );
        expect(
          await refused([(invoiceId: a, amountCents: 10001)]),
          PaymentRefusal.partBeyondInvoice,
        );
        final small = money.seedPayment(money.invoices.first.memberId, 12000);
        expect(
          await refused([
            (invoiceId: a, amountCents: 10000),
            (invoiceId: b, amountCents: 5000),
          ], id: small),
          PaymentRefusal.sumBeyondLeft,
        );
      },
    );

    test('an invoice that already holds a part of the payment is refused '
        'as used', () async {
      final (money, a, _, payment) = await _fixture();
      await money.applyPaymentToInvoices(
        workspaceId: 'ws-1',
        paymentLedgerId: payment,
        allocations: [(invoiceId: a, amountCents: 4000)],
        note: 'Partly paid',
      );
      await expectLater(
        money.applyPaymentToInvoices(
          workspaceId: 'ws-1',
          paymentLedgerId: payment,
          allocations: [(invoiceId: a, amountCents: 6000)],
        ),
        throwsA(
          isA<StateError>().having(
            PaymentRefusal.of,
            'reason',
            PaymentRefusal.usedMeanwhile,
          ),
        ),
      );
      expect(money.usedPaymentCents[payment], 4000, reason: 'unchanged');
    });
  });

  group('the parts of a payment', () {
    test('the invoices to pay: this customer, the business currency, open, '
        'oldest due first, no due date last', () {
      final rows = invoicesToPay(
        receivables: [
          _inv('late', 100, due: DateTime(2026, 6)),
          _inv('none', 100),
          _inv('early', 100, due: DateTime(2026, 5)),
          _inv('paid', 0),
          Receivable(
            invoiceId: 'usd',
            customerId: 'anna',
            customerName: 'Anna',
            number: 'U',
            currency: 'USD',
            totalMinor: 100,
            openMinor: 100,
            issuedOn: DateTime(2026, 4),
            stage: ReceivableStage.open,
          ),
        ],
        customerId: 'anna',
        currency: 'EUR',
      );
      expect(rows.map((r) => r.invoiceId), ['early', 'late', 'none']);
    });

    test(
      'the prefill uses the money up from the oldest; the last is a part',
      () {
        final rows = [_inv('a', 5000), _inv('b', 4000), _inv('c', 3000)];
        expect(prefillOldestFirst(rows, 7000), {'a': 5000, 'b': 2000});
        expect(prefillOldestFirst(rows, 20000), {
          'a': 5000,
          'b': 4000,
          'c': 3000,
        });
        expect(prefillOldestFirst(rows, 0), isEmpty);
      },
    );

    test('the plan: what stays, what is over, what needs a note', () {
      const due = {'a': 5000, 'b': 4000};
      PaymentPlan plan(int left, Map<String, int> parts) => PaymentPlan(
        leftCents: left,
        dueCents: due,
        parts: [
          for (final e in parts.entries)
            (invoiceId: e.key, amountCents: e.value),
        ],
      );
      final full = plan(10000, {'a': 5000, 'b': 4000});
      expect(full.staysCents, 1000);
      expect((full.fullCount, full.partCount), (2, 0));
      expect(full.canSend(note: ''), isTrue, reason: 'no part below its due');

      final part = plan(10000, {'a': 5000, 'b': 1000});
      expect((part.fullCount, part.partCount), (1, 1));
      expect(part.hasPartial, isTrue);
      expect(part.canSend(note: ' '), isFalse, reason: 'a note is required');
      expect(part.canSend(note: 'covered a part'), isTrue);

      final over = plan(8000, {'a': 5000, 'b': 4000});
      expect(over.overLeft, isTrue);
      expect(over.canSend(note: 'x'), isFalse);
      expect(plan(10000, {'a': 6000}).overDue, {'a'});
      expect(plan(10000, {}).canSend(note: 'x'), isFalse);
    });

    test('a refusal is told by its reason, never by the server English', () {
      PaymentRefusal of(String m) =>
          PaymentRefusal.of(PostgrestException(message: m));
      expect(of('an invoice is not of this payer'), PaymentRefusal.payer);
      expect(of('unknown payment'), PaymentRefusal.business);
      expect(
        of("an invoice is not in the business's currency"),
        PaymentRefusal.currency,
      );
      expect(of('an invoice appears twice'), PaymentRefusal.duplicate);
      expect(
        of('each part is a positive amount'),
        PaymentRefusal.partBeyondInvoice,
      );
      expect(
        of('the parts are more than what is left of the payment'),
        PaymentRefusal.sumBeyondLeft,
      );
      expect(
        of('the parts of a payment add up to more than the payment'),
        PaymentRefusal.usedMeanwhile,
      );
      expect(of('payment already matched'), PaymentRefusal.usedMeanwhile);
      expect(of('a note is required'), PaymentRefusal.noteRequired);
      expect(of('boom'), PaymentRefusal.generic);
      expect(PaymentRefusal.of(Exception('offline')), PaymentRefusal.generic);
    });
  });

  group('the record of what is left of a payment', () {
    LedgerEntry entry(int cents) => LedgerEntry(
      id: 'p',
      memberId: 'anna',
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: cents,
      description: 'T',
      period: '2026-03',
      createdAt: DateTime(2026, 3, 20),
    );

    test('received, assigned and left, the entry as received', () {
      final left = PaymentLeft.of(
        entry(12000),
        const PaymentUse(usedCents: {'p': 7000}),
      );
      expect(left.receivedCents, 12000);
      expect(left.assignedCents, 7000);
      expect(left.leftCents, 5000);
      expect(left.isPartlyUsed, isTrue);
      expect(left.entry.amountCents, 12000);
    });

    test('an unused payment is whole; a moved one has nothing left', () {
      final whole = PaymentLeft.of(entry(12000), PaymentUse.none);
      expect((whole.assignedCents, whole.leftCents), (0, 12000));
      expect(whole.isPartlyUsed, isFalse);
      final moved = PaymentLeft.of(
        entry(12000),
        const PaymentUse(moved: {'p'}),
      );
      expect(moved.leftCents, 0);
    });
  });
}
