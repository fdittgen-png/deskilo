// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4147 — a fresh Demo client resumes only the original own payment and
// its persisted money facts; ended claims never create a replacement or
// a second ledger credit.
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeMoneyRepository money;
  late Invoice invoice;
  late DateTime now;
  late PaymentOrderStart original;
  Future<PaymentOrderStart> resume({
    String? member,
    String? workspace,
    String? id,
  }) => DemoPaymentGateway(money).resumeClaimOrder(
    workspaceId: workspace ?? invoice.workspaceId,
    memberId: member ?? invoice.memberId,
    paymentId: id ?? original.orderId!,
  );
  PaymentIntent payment() => money.paymentIntents.single;

  setUp(() async {
    now = DateTime.utc(2026, 4, 30, 12);
    invoice = DemoFixture.build().money.invoices.singleWhere(
      (i) => i.id == 'demo-usage-chiara-extra',
    );
    money = FakeMoneyRepository(clock: () => now);
    money.invoices.clear();
    money.invoices.add(invoice);
    money.paymentIntents.clear();
    money.paymentGateway.standIn = true;
    original = await money.paymentGateway.createClaimOrder(
      provider: PaymentProvider.stripe,
      workspaceId: invoice.workspaceId,
      memberId: invoice.memberId,
      currencyCode: invoice.currency,
      requestId: 'original-request',
      claim: InvoiceClaim(
        period: invoice.period!,
        amountCents: invoice.totalCents,
        invoiceIds: [invoice.id],
      ),
    );
  });

  test(
    'fresh clients resume the original facts after the balance changes',
    () async {
      final persisted = payment();
      money.invoiceMatchesStore[invoice.id] = InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 1000,
        resolution: 'partial',
        matchedAt: now,
      );
      money.invoiceCommands.currency = 'GBP';
      final credits = money.ledger.length;
      for (var device = 0; device < 3; device++) {
        final start = await resume();
        expect(start.orderId, original.orderId);
        expect(start.approveUrl, original.approveUrl);
        expect(start.claimed, 1);
      }
      expect(payment(), same(persisted));
      expect(
        (
          payment().requestId,
          payment().provider,
          payment().amountCents,
          payment().currency,
        ),
        ('original-request', 'stripe', invoice.totalCents, 'EUR'),
      );
      expect(payment().claimedInvoiceIds, [invoice.id]);
      expect(money.paymentOrders, hasLength(1));
      expect(money.ledger, hasLength(credits));
    },
  );

  test(
    'repeated continuation and provider callbacks credit the order once',
    () async {
      final credits = money.ledger.length;
      final fresh = DemoPaymentGateway(money);
      await resume();
      await resume();
      await fresh.resolveOrder(original.orderId!, DemoPaymentOutcome.paid);
      await fresh.resolveOrder(original.orderId!, DemoPaymentOutcome.paid);
      expect(money.ledger.length, credits + 1);
      expect(
        money.invoiceMatchesStore[invoice.id]!.paidCents,
        invoice.totalCents,
      );
      expect(money.paymentIntents, hasLength(1));
      await expectLater(resume(), throwsA(isA<ClaimRefused>()));
    },
  );

  test(
    'other member, workspace and unknown payment share one refusal',
    () async {
      final unavailable = isA<ClaimRefused>().having(
        (e) => e.reason,
        'reason',
        ClaimRefusal.notProcessing,
      );
      await expectLater(resume(member: 'another-member'), throwsA(unavailable));
      await expectLater(
        resume(workspace: 'another-workspace'),
        throwsA(unavailable),
      );
      await expectLater(resume(id: 'unknown'), throwsA(unavailable));
      expect(money.paymentIntents, hasLength(1));
    },
  );

  for (final ended in ['failed', 'expired', 'withdrawn']) {
    test(
      '$ended cannot resume a stale overview or create another order',
      () async {
        switch (ended) {
          case 'failed':
            await money.paymentGateway.resolveOrder(
              original.orderId!,
              DemoPaymentOutcome.cancelled,
            );
          case 'expired':
            now = now.add(const Duration(hours: 24));
          case 'withdrawn':
            await money.accountCommands.withdrawPaymentClaim(
              workspaceId: invoice.workspaceId,
              paymentId: original.orderId!,
            );
        }
        expect(
          money.paymentGateway.continuationState(original.orderId!),
          ended,
        );
        await expectLater(resume(), throwsA(isA<ClaimRefused>()));
        expect(money.paymentIntents, hasLength(1));
        expect(money.paymentOrders, hasLength(1));
      },
    );
  }

  test(
    'a legacy intent without a request cannot invent a replacement',
    () async {
      final p = payment();
      money.paymentIntents[0] = PaymentIntent(
        id: p.id,
        memberId: p.memberId,
        provider: p.provider,
        orderId: p.orderId,
        period: p.period,
        amountCents: p.amountCents,
        status: p.status,
        createdAt: p.createdAt,
        currency: p.currency,
        claimedInvoiceIds: p.claimedInvoiceIds,
      );
      expect(
        money.paymentGateway.continuationState(original.orderId!),
        'unavailable',
      );
      await expectLater(resume(), throwsA(isA<ClaimRefused>()));
      expect(money.paymentOrders, hasLength(1));
    },
  );
}
