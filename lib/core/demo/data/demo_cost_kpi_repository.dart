// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The cost figures of a city space (#2582), computed over that space's own
// purchase documents and invoices: what a server's `kpi_costs_summary` reads,
// reduced to what the Demo holds. A figure the Demo has no source for (book
// depreciation, what a contract still expects) is null and says why, never 0.
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_purchases.dart';
import '../../time/date_text.dart';
import 'purchase_repository.dart';

class DemoCostKpiRepository implements CostKpiRepository {
  DemoCostKpiRepository({
    required this.purchases,
    required this.invoices,
    required this.now,
    required this.currency,
  });

  final FakePurchaseRepository purchases;
  final List<Invoice> Function() invoices;
  final DateTime now;
  final String currency;

  static String _month(DateTime d) => yearMonth(d.year, d.month);

  @override
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    bool inRange(DateTime? d) {
      if (d == null) return false;
      final m = _month(d);
      return m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
    }

    var operating = 0, acquisitions = 0, unresolved = 0;
    for (final doc in purchases.documents) {
      final s = doc.summary;
      if (s.state != PurchaseState.approved || s.currency != currency) continue;
      if (!inRange(s.originalDate ?? s.receivedOn)) continue;
      for (final line in doc.lines) {
        final amount = line.netCents ?? line.grossCents;
        switch (line.recognitionKind) {
          case 'expense':
            operating += amount + (line.taxCents ?? 0) - (line.recoverableTaxCents ?? line.taxCents ?? 0);
          case 'asset':
            acquisitions += amount;
          case 'unresolved':
            unresolved++;
        }
      }
    }
    final sales = invoices()
        .where((i) => !i.isVoided && i.currency == currency && inRange(i.issuedAt))
        .fold<int>(0, (sum, i) => sum + i.netCents);
    final partial = toMonth.compareTo(_month(now)) >= 0;
    return CostSummaryKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      operatingCostsMinor: operating,
      acquisitionsMinor: acquisitions,
      netSalesMinor: sales,
      contributionMinor: sales - operating,
      unresolvedLines: unresolved,
      unqualifiedLines: 0,
      bookDepreciationMinor: null,
      afterDepreciationMinor: null,
      unbilledMinor: null,
      unbilledOverdueMinor: null,
      unbilledUpcomingMinor: null,
      forecastMinor: null,
      quality: {if (partial) KpiQuality.partial},
      reasons: [if (partial) 'period_not_over'],
      computedAt: now,
    );
  }
}
