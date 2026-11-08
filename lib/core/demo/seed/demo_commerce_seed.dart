// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — commerce and tax in the demo: Bruno's negotiated tariff (one in
// force, the next one waiting for its second validation), prepaid
// carnets with a balance to spend, and the VAT declarations of the last
// two quarters — one submitted, one a draft — computed from the bills the
// session actually holds.

import '../../../features/money/domain/accounting_view.dart';
import '../../../features/money/domain/credit_product.dart';
import '../../../features/money/domain/price_negotiation.dart';
import '../../../features/money/domain/vat_declaration.dart';
import '../../../features/money/domain/vat_period_lock.dart';
import '../../../features/money/domain/vat_tax_point.dart';
import '../data/book_profile_repository.dart' show demoDayOf, demoTaxReference;
import '../data/credit_repository.dart';
import '../data/money_repository.dart';

void seedDemoNegotiations(FakeMoneyRepository money, DateTime now) {
  money.negotiations['member-2'] = PriceNegotiation(
    defaultFeeCents: 9000,
    defaultOverageFeeCents: 800,
    active: NegotiationDeal(
      feeCents: 8500,
      note: 'Long-standing member',
      validFrom: DateTime(now.year),
      status: 'confirmed',
      subscriptionPct: 50,
    ),
    // The proposal waiting in the decisions (demo_decision_seed.dart).
    pending: NegotiationDeal(
      feeCents: 8000,
      discountPercent: 10,
      validFrom: DateTime(now.year, now.month + 1),
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
  // French service VAT is due on receipts unless the issuer opted for
  // debits. Keep seeded returns and subsequent preparations on that basis.
  money.vatReturnBasis = vatTaxPointBasis(
    'FR',
    null,
    reference: demoTaxReference(),
  );
  final view = accountingView(money.invoices, money.invoiceMatchesStore);
  final ledger = vatTaxPointLedger(
    view.invoices,
    matches: view.matches,
    instalments: money.invoiceInstalmentsStore,
    basis: money.vatReturnBasis,
    reference: demoTaxReference(),
    dayOf: demoDayOf,
  );
  final quarter = (now.month - 1) ~/ 3;
  final thisQuarter = DateTime(now.year, quarter * 3 + 1);
  VatDeclaration declaration(DateTime start, {required bool submitted}) {
    final end = DateTime(start.year, start.month + 3, 0);
    final amounts = vatReturnAmountsOf(
      ledger,
      start: start,
      end: end,
      locks: vatPeriodLocksOf(money.vatDeclarations),
      declared: money.vatDeclared,
    );
    final lines = vatReturnLinesOf(
      amounts,
      declarations: money.vatDeclarations,
    );
    if (submitted) money.vatDeclared.addAll(vatDeclaredBy(amounts));
    final net = lines.fold(0, (int n, line) => n + line.netCents);
    final vat = lines.fold(0, (int n, line) => n + line.vatCents);
    final count = amounts.map((a) => a.invoiceId).toSet().length;
    final label = 'T${(start.month - 1) ~/ 3 + 1}';
    return VatDeclaration(
      id: 'demo-vat-${start.year}-$label',
      workspaceId: 'ws-1',
      periodStart: start,
      periodEnd: end,
      status: submitted ? 'filed' : 'prepared',
      lines: lines,
      totalNetCents: net,
      totalVatCents: vat,
      currency: 'EUR',
      invoiceCount: count,
      createdAt: end.add(const Duration(days: 5)).isAfter(now)
          ? now
          : end.add(const Duration(days: 5)),
      submittedAt: submitted ? end.add(const Duration(days: 12)) : null,
      submittedChannel: submitted ? 'manual' : '',
      submittedReceipt: submitted ? 'EFI-${start.year}-$label' : '',
      number: submitted ? 'CA3-${start.year}-$label' : '',
    );
  }

  money.vatDeclarations.add(
    declaration(
      DateTime(thisQuarter.year, thisQuarter.month - 6),
      submitted: true,
    ),
  );
  money.vatDeclarations.add(
    declaration(
      DateTime(thisQuarter.year, thisQuarter.month - 3),
      submitted: false,
    ),
  );
}
