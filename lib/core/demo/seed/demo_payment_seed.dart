// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — the online payments the reference business already holds when the
// Demo opens, on the Demo's day, each of a bill that exists: one captured (its
// bill paid), one failed (a card that was declined), one captured and then
// reversed by the provider (waiting for someone who sees the finances), one
// whose order the provider never answered. Amounts are the bills' own, in the
// business's currency; the reversal names its amount and currency.
import 'package:deskilo/features/money/domain/payment_intent.dart';

import '../data/money_repository.dart';

/// Seeds the intents of the Demo's online payments on [money], and tells its
/// gateway to stand in for the provider's page.
void seedDemoOnlinePayments(FakeMoneyRepository money, DateTime now) {
  money.paymentGateway.standIn = true;
  PaymentIntent intent(
    String invoiceId,
    String status, {
    required int daysAgo,
    int? cents,
    DateTime? reversedAt,
    String reason = '',
  }) {
    final invoice = money.invoices.firstWhere((i) => i.id == invoiceId);
    final n = money.paymentIntents.length + 1;
    final at = now.subtract(Duration(days: daysAgo));
    return PaymentIntent(
      id: 'demo-intent-$n',
      memberId: invoice.memberId,
      provider: 'paypal',
      orderId: 'demo-order-$n',
      period: invoice.period ?? '',
      amountCents: cents ?? invoice.totalCents,
      status: status,
      createdAt: at,
      captureId: status == 'captured' || status == 'reversed'
          ? 'demo-seed-capture-$n'
          : '',
      reference: 'PAY-${at.year}-${n.toString().padLeft(4, '0')}',
      reversedAt: reversedAt,
      reversalReason: reason,
    );
  }

  final reversed = money.invoices.firstWhere((i) => i.id == 'demo-usage-ada-a');
  final reversedAmount = (reversed.totalCents / 100).toStringAsFixed(2);
  // The list grows one by one: each intent numbers itself from the list.
  void add(PaymentIntent p) => money.paymentIntents.add(p);
  // Ada's bill of the month, paid online.
  add(intent('demo-invoice-ada', 'captured', daysAgo: 14));
  // Bruno's card was declined; he has not paid yet.
  add(intent('demo-usage-bruno', 'failed', daysAgo: 6));
  // Ada paid a usage bill online, and the provider took it back.
  add(
    intent(
      'demo-usage-ada-a',
      'reversed',
      daysAgo: 40,
      reversedAt: now.subtract(const Duration(days: 3)),
      reason: 'Chargeback $reversedAmount ${reversed.currency}',
    ),
  );
  // Chiara's payment: the provider never answered.
  add(intent('demo-usage-chiara-c', 'created', daysAgo: 2, cents: 11327));
}
