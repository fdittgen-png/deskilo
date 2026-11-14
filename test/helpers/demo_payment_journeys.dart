// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — the online payment of the reference business, through the app's
// own provider: the order the app starts, the page that stands for the
// provider's, and what each answer leaves in the books. Shared by the
// scenario checklist and the outcome test.
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_outbox_journeys.dart';

/// Bruno's two open bills of the Demo's last month: what he can pay online.
const bruno = 'member-2';

/// The Demo's gateway of a session, as the app's provider hands it out.
DemoPaymentGateway gatewayOf(ProviderContainer c) =>
    c.read(paymentGatewayRepositoryProvider) as DemoPaymentGateway;

/// What a member's books say: the payments credited, the cents paid on the
/// invoices of [period], and what is still due on them.
typedef Figures = ({int credited, int paid, int due, int captured});

Figures figuresOf(DemoFixture f, String memberId, String period) {
  final m = f.money;
  final invoices = [
    for (final i in m.invoices)
      if (i.memberId == memberId && i.period == period && i.totalCents > 0) i,
  ];
  final paid = invoices.fold(
    0,
    (t, i) => t + (m.invoiceMatchesStore[i.id]?.paidCents ?? 0),
  );
  return (
    credited: m.ledger
        .where(
          (e) =>
              e.memberId == memberId &&
              e.kind == LedgerKind.credit &&
              e.category == LedgerCategory.payment &&
              e.description.startsWith('Online payment'),
        )
        .fold(0, (t, e) => t + e.amountCents),
    paid: paid,
    due: invoices.fold(0, (t, i) => t + i.totalCents) - paid,
    captured: m.paymentIntents
        .where(
          (p) =>
              p.memberId == memberId &&
              p.period == period &&
              p.status == 'captured' &&
              p.captureId.startsWith('demo-capture'),
        )
        .fold(0, (t, p) => t + p.amountCents),
  );
}

/// The period Bruno's open bills are of.
String brunoPeriod(DemoFixture f) =>
    f.money.invoices.firstWhere((i) => i.id == 'demo-invoice-bruno').period!;

/// Starts the order the app starts for [amountCents] of Bruno's bill.
Future<PaymentOrderStart> startOrder(
  ProviderContainer c,
  DemoFixture f,
  int amountCents, {
  String requestId = 'req-1',
}) => gatewayOf(c).createPaymentOrder(
  provider: PaymentProvider.paypal,
  workspaceId: 'ws-1',
  memberId: bruno,
  amountCents: amountCents,
  currencyCode: 'EUR',
  period: brunoPeriod(f),
  requestId: requestId,
);

PaymentIntent intentOf(DemoFixture f, String? orderId) =>
    f.money.paymentIntents.firstWhere((p) => p.orderId == orderId);

/// Bruno pays: the order is started, the stand-in page answers "pay", and
/// the books, the invoices and the payments list tell the same story.
Future<bool> onlinePaymentJourney() => withDemoSession((f, outbox, c) async {
  final period = brunoPeriod(f);
  final before = figuresOf(f, bruno, period);
  final start = await startOrder(c, f, before.due);
  final intent = intentOf(f, start.orderId);
  final created = start.started && intent.status == 'created';
  await gatewayOf(c).resolveOrder(start.orderId!, DemoPaymentOutcome.paid);
  final after = figuresOf(f, bruno, period);
  return created &&
      intentOf(f, start.orderId).status == 'captured' &&
      after.credited == before.credited + before.due &&
      after.paid == before.paid + before.due &&
      after.due == 0 &&
      after.captured == before.captured + before.due;
});
