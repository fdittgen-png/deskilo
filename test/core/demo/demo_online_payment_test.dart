// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — an online payment in the reference business: paid, cancelled, left
// uncertain and reversed. The provider's page is the Demo's stand-in; each
// answer leaves the books, the invoices and the payments list telling one
// story, and a second confirmation of the same order never credits twice.
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_outbox_journeys.dart';
import '../../helpers/demo_payment_journeys.dart';

void main() {
  test('the Demo opens with one intent of each kind, in euros', () async {
    await withDemoSession((f, outbox, c) async {
      final intents = await gatewayOf(c).fetchPaymentIntents('ws-1');
      expect(intents.map((p) => p.status).toSet(), {
        'captured',
        'failed',
        'reversed',
        'created',
      });
      for (final p in intents) {
        expect(p.reference, startsWith('PAY-'));
        expect(p.createdAt.isAfter(f.seededAt), isFalse);
      }
      final reversed = intents.singleWhere((p) => p.status == 'reversed');
      expect(reversed.awaitsReview, isTrue);
      expect(reversed.reversedMinor('EUR'), isNotNull);
      expect(reversed.reversedAt, isNotNull);
      // The captured one is of a bill that is paid.
      final captured = intents.firstWhere((p) => p.status == 'captured');
      final paid = [
        for (final i in f.money.invoices)
          if (i.memberId == captured.memberId && i.period == captured.period)
            f.money.invoiceMatchesStore[i.id]?.paidCents ?? 0,
      ].fold(0, (a, b) => a + b);
      expect(paid, greaterThanOrEqualTo(captured.amountCents));
    });
  });

  test('a member pays: captured, credited once, the bill paid', () async {
    expect(await onlinePaymentJourney(), isTrue);
  });

  test('a part payment leaves the rest due, and the books agree', () async {
    await withDemoSession((f, outbox, c) async {
      final period = brunoPeriod(f);
      final before = figuresOf(f, bruno, period);
      final start = await startOrder(c, f, 5000);
      await gatewayOf(c).resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
      final after = figuresOf(f, bruno, period);
      expect(after.credited, before.credited + 5000);
      expect(after.paid, before.paid + 5000);
      expect(after.due, before.due - 5000);
      expect(after.captured, before.captured + 5000);
    });
  });

  test('cancelled: the intent failed and the bill is still open', () async {
    await withDemoSession((f, outbox, c) async {
      final period = brunoPeriod(f);
      final before = figuresOf(f, bruno, period);
      final start = await startOrder(c, f, before.due);
      await gatewayOf(c)
          .resolveOrder(start.orderId!, DemoPaymentOutcome.cancelled);
      expect(intentOf(f, start.orderId).status, 'failed');
      expect(figuresOf(f, bruno, period), before);
    });
  });

  test('no answer: the order stays uncertain, and a late answer settles it '
      'once', () async {
    await withDemoSession((f, outbox, c) async {
      final period = brunoPeriod(f);
      final before = figuresOf(f, bruno, period);
      final start = await startOrder(c, f, before.due);
      await gatewayOf(c)
          .resolveOrder(start.orderId!, DemoPaymentOutcome.noAnswer);
      expect(intentOf(f, start.orderId).status, 'created');
      expect(figuresOf(f, bruno, period), before);
      // The provider answers later: the same order, never a second credit.
      await gatewayOf(c).resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
      await gatewayOf(c).resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
      final after = figuresOf(f, bruno, period);
      expect(after.credited, before.credited + before.due);
      expect(after.due, 0);
    });
  });

  test(
    'a retried request is the same order; a paid one is not opened again',
    () async {
      await withDemoSession((f, outbox, c) async {
        final period = brunoPeriod(f);
        final due = figuresOf(f, bruno, period).due;
        final first = await startOrder(c, f, due);
        final again = await startOrder(c, f, due);
        expect(again.orderId, first.orderId);
        await gatewayOf(c)
            .resolveOrder(first.orderId!, DemoPaymentOutcome.paid);
        final paid = await startOrder(c, f, due);
        expect(paid.alreadyPaid, isTrue);
        expect(figuresOf(f, bruno, period).credited, due);
      });
    },
  );

  test('a payment the provider reverses is marked and waits for review, '
      'the books untouched', () async {
    await withDemoSession((f, outbox, c) async {
      final period = brunoPeriod(f);
      final start = await startOrder(c, f, 5000);
      final gateway = gatewayOf(c);
      await gateway.resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
      final credited = figuresOf(f, bruno, period);
      await gateway.reverseOrder(start.orderId!, 'Chargeback 50.00 EUR');
      final intent = intentOf(f, start.orderId);
      expect(intent.status, 'reversed');
      expect(intent.awaitsReview, isTrue);
      expect(intent.reversedMinor('EUR'), 5000);
      expect(figuresOf(f, bruno, period).credited, credited.credited);
      // A late capture never credits a reversed payment again.
      await gateway.resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
      expect(figuresOf(f, bruno, period).credited, credited.credited);
      await gateway.reviewPaymentReversal(intent.id);
      expect(intentOf(f, start.orderId).awaitsReview, isFalse);
    });
  });
}
