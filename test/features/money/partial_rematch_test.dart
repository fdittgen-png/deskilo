// SPDX-License-Identifier: 0BSD
//
// Additional payments onto a PARTIALLY PAID invoice (#506): matched
// against the REMAINING amount — maybe until fully paid, maybe the
// rest is written off (#504).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';
import 'invoice_writeoff_test.dart' show partialMatch;
import 'invoices_test.dart' show seededMoney;

void main() {
  test('a second payment covering the REMAINDER settles the invoice — '
      'the aggregate flips to exact and the lifecycle to paid (#506)',
      () async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single; // €250.00
    // €10.00 paid so far; the rest arrives as a second payment.
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id).copyWith(paidCents: 1000);
    final paymentId =
        money.seedPayment(invoice.memberId, invoice.totalCents - 1000);

    await money.matchInvoice(
      invoiceId: invoice.id,
      paymentLedgerId: paymentId,
      resolution: 'exact',
    );

    final match = money.invoiceMatchesStore[invoice.id]!;
    expect(match.paidCents, invoice.totalCents);
    expect(match.resolution, 'exact');
    expect(money.consumedPaymentIds, contains(paymentId));
  });

  test('a second payment SMALLER than the remainder keeps the invoice '
      'partial — the aggregate grows (#506)', () async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id).copyWith(paidCents: 1000);
    final paymentId = money.seedPayment(invoice.memberId, 500);

    await money.matchInvoice(
      invoiceId: invoice.id,
      paymentLedgerId: paymentId,
      resolution: 'under_accepted',
      note: 'second instalment',
    );

    final match = money.invoiceMatchesStore[invoice.id]!;
    expect(match.paidCents, 1500);
    expect(match.resolution, 'under_accepted');
  });

  test('the amount rules compare against the REMAINDER, not the total '
      '(#506)', () async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id).copyWith(paidCents: 1000);
    // A payment equal to the ORIGINAL total is no longer 'exact' — the
    // remainder is smaller now.
    final paymentId =
        money.seedPayment(invoice.memberId, invoice.totalCents);

    await expectLater(
      money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: paymentId,
        resolution: 'exact',
      ),
      throwsStateError,
    );
  });

  test('a written-off or fully matched invoice refuses further '
      'payments (#506)', () async {
    final money = await seededMoney(matched: false);
    final invoice = money.invoices.single;
    money.invoiceMatchesStore[invoice.id] =
        partialMatch(invoice.id, writeoffAt: kTestNow)
            .copyWith(paidCents: 1000);
    final paymentId =
        money.seedPayment(invoice.memberId, invoice.totalCents - 1000);

    await expectLater(
      money.matchInvoice(
        invoiceId: invoice.id,
        paymentLedgerId: paymentId,
        resolution: 'exact',
      ),
      throwsStateError,
    );
  });

  test('migration 0101 adds the payments junction, reserves payments '
      'while pending, and applies additions on confirm', () {
    final sql = File('supabase/migrations/0101_partial_rematch.sql')
        .readAsStringSync();
    expect(sql, contains('invoice_match_payments'));
    expect(sql, contains("v_due := v_invoice.total_cents - v_existing.paid_cents"));
    expect(sql, contains("'additional', v_additional"));
    expect(sql, contains('paid_cents = m.paid_cents + jr.amount_cents'));
    // The verbatim-generated respond body keeps the earlier branches.
    expect(sql, contains("v_event.type = 'invoice_writeoff'"));
    expect(sql, contains("v_event.type = 'reservation_delete'"));
    expect(sql, contains("(v_event.payload->>'reservation_id')::uuid"));
  });
}
