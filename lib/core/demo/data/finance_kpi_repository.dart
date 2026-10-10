// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the demonstration's finance KPIs, summed from its own invoices
// and matches the way `finance_summary` sums them on a server, so the
// Business analytics cards show the same money the Money pages show
// instead of "unavailable".
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';

import 'money_repository.dart';

class DemoFinanceKpiRepository implements FinanceKpiRepository {
  DemoFinanceKpiRepository(this.money, {required this.now});

  final FakeMoneyRepository money;

  /// The demonstration's clock.
  final DateTime now;

  @override
  Future<FinanceSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    bool inRange(String? month) =>
        month != null &&
        month.compareTo(fromMonth) >= 0 &&
        month.compareTo(toMonth) <= 0;
    String monthOf(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
    final invoices = money.invoices
        .where(
          (i) =>
              i.voidedAt == null &&
              i.kind != InvoiceKind.settlement &&
              inRange(i.period),
        )
        .toList();
    final matches = money.invoiceMatchesStore.values
        .where((m) => inRange(monthOf(m.matchedAt)))
        .toList();
    final invoiced = invoices
        .where((i) => i.totalCents > 0)
        .fold(0, (sum, i) => sum + i.totalCents);
    final creditNotes = -invoices
        .where((i) => i.totalCents < 0)
        .fold(0, (sum, i) => sum + i.totalCents);
    final collected = matches.fold(0, (sum, m) => sum + m.paidCents);
    return FinanceSummaryKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: 'EUR',
      invoicedMinor: invoiced,
      creditNotesMinor: creditNotes,
      collectedMinor: collected,
      invoices: invoices.length,
      matches: matches.length,
      quality: {if (invoiced == 0 && collected == 0) KpiQuality.knownZero},
      reasons: const [],
      computedAt: now,
    );
  }
}
