// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — commerce and tax in the demo: Bruno's negotiated tariff (one in
// force, the next one waiting for its second validation), prepaid
// carnets with a balance to spend, and the VAT declarations of the last
// two quarters — one submitted, one a draft — computed from the bills the
// session actually holds.
import '../../../features/money/domain/credit_product.dart';
import '../../../features/money/domain/price_negotiation.dart';
import '../../../features/money/domain/vat_declaration.dart';
import '../data/credit_repository.dart';
import '../data/money_repository.dart';

void seedDemoNegotiations(FakeMoneyRepository money, DateTime now) {
  money.negotiations['member-2'] = PriceNegotiation(
    defaultFeeCents: 9000,
    defaultOverageFeeCents: 800,
    active: NegotiationDeal(
      feeCents: 8500,
      note: 'Long-standing member',
      validFrom: DateTime(now.year, 1, 1),
      status: 'confirmed',
      subscriptionPct: 50,
    ),
    // The proposal waiting in the decisions (demo_decision_seed.dart).
    pending: NegotiationDeal(
      feeCents: 8000,
      discountPercent: 10,
      validFrom: DateTime(now.year, now.month + 1, 1),
      status: 'pending',
      subscriptionPct: 50,
      previousSubscriptionPct: 50,
    ),
  );
}

void seedDemoCarnets(FakeCreditRepository credits) {
  credits.products.addAll(const [
    CreditProduct(
      id: 'demo-carnet-10',
      name: '10 half-days',
      halfDays: 10,
      priceCents: 15000,
      validityMonths: 6,
    ),
    CreditProduct(
      id: 'demo-carnet-20',
      name: '20 half-days',
      halfDays: 20,
      priceCents: 28000,
      validityMonths: 12,
    ),
  ]);
  credits.balances['member-2'] = 6;
}

/// The last two quarters' declarations, from the session's own bills.
void seedDemoVatDeclarations(FakeMoneyRepository money, DateTime now) {
  final quarter = (now.month - 1) ~/ 3;
  final thisQuarter = DateTime(now.year, quarter * 3 + 1, 1);
  VatDeclaration declaration(DateTime start, {required bool submitted}) {
    final end = DateTime(start.year, start.month + 3, 0);
    final bills = [
      for (final i in money.invoices)
        if (!i.issuedAt.isBefore(start) &&
            !i.issuedAt.isAfter(end) &&
            i.totalCents > 0)
          i,
    ];
    final gross = bills.fold(0, (n, i) => n + i.totalCents);
    final net = (gross / 1.2).round();
    final label = 'T${(start.month - 1) ~/ 3 + 1}';
    return VatDeclaration(
      id: 'demo-vat-${start.year}-$label',
      workspaceId: 'ws-1',
      periodStart: start,
      periodEnd: end,
      status: submitted ? 'submitted' : 'draft',
      lines: [
        VatDeclarationLine(
          percent: 20,
          grossCents: gross,
          netCents: net,
          vatCents: gross - net,
          invoiceCount: bills.length,
        ),
      ],
      totalNetCents: net,
      totalVatCents: gross - net,
      currency: 'EUR',
      invoiceCount: bills.length,
      createdAt: end.add(const Duration(days: 5)),
      submittedAt: submitted ? end.add(const Duration(days: 12)) : null,
      submittedChannel: submitted ? 'manual' : '',
      number: submitted ? 'CA3-${start.year}-$label' : '',
    );
  }

  money.vatDeclarations.addAll([
    declaration(
      DateTime(thisQuarter.year, thisQuarter.month - 6, 1),
      submitted: true,
    ),
    declaration(
      DateTime(thisQuarter.year, thisQuarter.month - 3, 1),
      submitted: false,
    ),
  ]);
}
