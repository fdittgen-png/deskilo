// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 / #3785 — the cost figures of a Demo space, computed over that
// space's own purchase documents, equipment register, book values, lease
// occurrences and invoices with the rules of `kpi_costs_summary` (0532):
//
//   * a line's cost is its net plus the tax that cannot be recovered; the
//     gross when the recoverable share is not qualified or the line states
//     no tax; a supplier credit note subtracts (0532 `with lines`);
//   * operating costs are the approved lines classified `operating`,
//     dated by the document (the supplier's date, else the day it arrived);
//   * acquisitions are the `asset` lines of an equipment register entry
//     decided `capitalise`; unknown while the register is off;
//   * the invoiced sales are the invoices of the months, net of their tax,
//     settlements and voided ones left out;
//   * the book depreciation is known only when confirmed, complete
//     period-movement book batches in the space's currency tile the months
//     exactly (#2576), never 0 otherwise;
//   * the unbilled commitments are what the contract schedules (each lease
//     term, each room rented at a fixed cost) still expect in the months:
//     a generated occurrence less its matched bills, the ones not generated
//     yet projected within the schedule's end (demo_contract_schedules.dart);
//   * the forecast is what the space owes its suppliers at the end of the
//     months plus those commitments.
//
// Another currency on an operating or asset line, or on an invoice of the
// months, leaves every amount unknown (`currency_mix`), never summed.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/asset_valuation.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/workspace_asset.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_purchases.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import 'asset_valuation_repository.dart';
import 'demo_contract_schedules.dart';
import 'kpi_repositories.dart';
import 'lease_commitment_repository.dart';
import 'premises_lease_repository.dart';
import 'purchase_repository.dart';
import 'room_rental_repository.dart';
import 'workspace_asset_repository.dart';

/// What one Demo space's cost figures are computed from.
typedef DemoCostSources = ({
  FakePurchaseRepository purchases,
  List<Invoice> Function() invoices,
  FakeWorkspaceAssetRepository assets,
  FakeAssetValuationRepository valuations,
  FakeLeaseCommitmentRepository commitments,
  FakePremisesLeaseRepository leases,
  FakeRoomRentalRepository rooms,
});

/// The figures of the purchase lines of the months.
typedef _Lines = ({
  int operating,
  int acquisitions,
  int unresolved,
  int unqualified,
  bool mixed,
});

/// Every purchase document of the space with its lines, as the purchases
/// page lists and opens them: the documents and the receipts of the claims.
Future<List<PurchaseDetail>> demoPurchaseDocuments(
  FakePurchaseRepository purchases,
  String workspaceId,
) async => [
  for (final s in await purchases.fetchPurchases(workspaceId))
    await purchases.fetchDetail(workspaceId, s.id),
];

class DemoCostKpiRepository implements CostKpiRepository {
  DemoCostKpiRepository({
    required this.sources,
    required this.currencyOf,
    required this.features,
    required this.now,
  });

  final DemoCostSources sources;

  /// The space's currency, as its workspace record states it.
  final String Function(String workspaceId) currencyOf;

  /// The features in force for the space being read.
  final Set<WorkspaceFeature> Function() features;
  final DateTime now;

  static String _month(DateTime d) => yearMonth(d.year, d.month);

  /// 0532's cost of one line: net plus what cannot be recovered; the gross
  /// without a stated tax; net plus the whole tax while the recoverable
  /// share is not qualified.
  static int lineCost(PurchaseLine l) {
    final net = l.netCents;
    if (net == null) return l.grossCents;
    final tax = l.taxCents ?? 0;
    final recoverable = l.recoverableTaxCents;
    return recoverable == null ? net + tax : net + tax - recoverable;
  }

  @override
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    final currency = currencyOf(workspaceId).trim().toUpperCase();
    if (currency.isEmpty) {
      throw const KpiUnavailable('the workspace has no currency');
    }
    bool inMonths(DateTime? d) {
      if (d == null) return false;
      final m = _month(d);
      return m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
    }

    final on = features();
    final assetsOn = on.contains(WorkspaceFeature.assetRegister);
    final contractsOn =
        on.contains(WorkspaceFeature.premisesLease) ||
        on.contains(WorkspaceFeature.externalRooms);
    final lines = _lines(
      await demoPurchaseDocuments(sources.purchases, workspaceId),
      currency,
      inMonths,
    );
    final sales = _sales(workspaceId, currency, fromMonth, toMonth);
    final depreciation = assetsOn
        ? _depreciation(currency, fromMonth, toMonth)
        : null;
    final unbilled = contractsOn ? _unbilled(fromMonth, toMonth) : null;
    final ap = contractsOn
        ? (await DemoPurchaseKpiRepository(
                purchases: sources.purchases,
                now: now,
                currency: currency,
              ).summary(workspaceId, fromMonth: fromMonth, toMonth: toMonth))
              .apOutstandingMinor
        : null;
    final mixed = lines.mixed || sales.mixed;
    final partial = toMonth.compareTo(_month(now)) >= 0;
    final contribution = sales.net - lines.operating;
    return CostSummaryKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      operatingCostsMinor: lines.operating,
      acquisitionsMinor: assetsOn ? lines.acquisitions : null,
      netSalesMinor: sales.net,
      contributionMinor: contribution,
      unresolvedLines: lines.unresolved,
      unqualifiedLines: lines.unqualified,
      bookDepreciationMinor: depreciation,
      afterDepreciationMinor: depreciation == null
          ? null
          : contribution - depreciation,
      unbilledMinor: unbilled?.total,
      unbilledOverdueMinor: unbilled?.overdue,
      unbilledUpcomingMinor: unbilled == null
          ? null
          : unbilled.total - unbilled.overdue,
      forecastMinor: unbilled == null || ap == null
          ? null
          : ap + unbilled.total,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [
        if (mixed) 'currency_mix',
        if (partial) 'period_not_over',
        if (lines.unqualified > 0) 'tax_unqualified',
        if (lines.unresolved > 0) 'unresolved_lines',
        if (!assetsOn)
          'asset_register_off'
        else if (depreciation == null)
          'book_coverage_incomplete',
        if (!contractsOn) 'no_contracts',
      ],
      computedAt: now,
    );
  }

  /// The approved lines of the months, by their classification.
  _Lines _lines(
    List<PurchaseDetail> documents,
    String currency,
    bool Function(DateTime?) inMonths,
  ) {
    final capitalised = {
      for (final a in sources.assets.assets)
        if (a.decision == AssetDecision.capitalise)
          '${a.purchaseId}#${a.lineNo}',
    };
    var operating = 0, acquisitions = 0, unresolved = 0, unqualified = 0;
    var mixed = false;
    for (final doc in documents) {
      final s = doc.summary;
      if (s.state != PurchaseState.approved) continue;
      if (!inMonths(s.originalDate ?? s.receivedOn)) continue;
      final sign = s.kind == PurchaseKind.creditNote ? -1 : 1;
      final foreign = s.currency.toUpperCase() != currency;
      for (final line in doc.lines) {
        switch (line.recognitionKind) {
          case 'operating':
            operating += sign * lineCost(line);
            mixed |= foreign;
            if (line.netCents != null &&
                (line.taxCents ?? 0) != 0 &&
                line.recoverableTaxCents == null) {
              unqualified++;
            }
          case 'asset':
            mixed |= foreign;
            if (capitalised.contains('${s.id}#${line.lineNo}')) {
              acquisitions += sign * lineCost(line);
            }
          case 'unresolved':
            unresolved++;
        }
      }
    }
    return (
      operating: operating,
      acquisitions: acquisitions,
      unresolved: unresolved,
      unqualified: unqualified,
      mixed: mixed,
    );
  }

  /// The invoiced sales of the months, net of their tax: the documents
  /// `finance.invoiced` reads (non-void, settlements left out), credit notes
  /// subtracting.
  ({int net, bool mixed}) _sales(
    String workspaceId,
    String currency,
    String fromMonth,
    String toMonth,
  ) {
    var net = 0;
    var mixed = false;
    for (final i in sources.invoices()) {
      final period = i.period;
      if (i.workspaceId != workspaceId ||
          i.isVoided ||
          i.kind == InvoiceKind.settlement ||
          period == null ||
          period.compareTo(fromMonth) < 0 ||
          period.compareTo(toMonth) > 0) {
        continue;
      }
      net += i.netCents;
      if (i.currency.isNotEmpty && i.currency.toUpperCase() != currency) {
        mixed = true;
      }
    }
    return (net: net, mixed: mixed);
  }

  /// The book depreciation of the months, or null when the confirmed book
  /// batches do not tile them exactly (#2576).
  int? _depreciation(String currency, String fromMonth, String toMonth) {
    final start = _firstDay(fromMonth);
    final cut = _lastDay(toMonth);
    final batches = [
      for (final b in sources.valuations.batches)
        if (b.basis == ValuationBasis.book &&
            b.status == ValuationStatus.confirmed &&
            !_day(b.periodFrom).isAfter(cut) &&
            !_day(b.periodTo).isBefore(start))
          b,
    ];
    if (batches.isEmpty) return null;
    final rows = [for (final b in batches) ...?sources.valuations.rows[b.id]];
    final whole = batches.every(
      (b) =>
          b.movements == 'period' &&
          b.completeScope &&
          b.currency.toUpperCase() == currency &&
          !_day(b.periodFrom).isBefore(start) &&
          !_day(b.periodTo).isAfter(cut),
    );
    if (!whole ||
        !_tiles(batches, start, cut) ||
        rows.any((r) => r.depreciationMinor == null)) {
      return null;
    }
    return rows.fold<int>(0, (s, r) => s + r.depreciationMinor!);
  }

  /// Whether [batches] cover [start, cut] exactly once: they begin on the
  /// first day, end on the last, overlap nowhere and add up to every day.
  static bool _tiles(
    List<ValuationBatch> batches,
    DateTime start,
    DateTime cut,
  ) {
    final sorted = [...batches]
      ..sort((a, b) => a.periodFrom.compareTo(b.periodFrom));
    var days = 0;
    for (var i = 0; i < sorted.length; i++) {
      final from = _day(sorted[i].periodFrom), to = _day(sorted[i].periodTo);
      days += _days(from, to) + 1;
      if (i > 0 && !from.isAfter(_day(sorted[i - 1].periodTo))) return false;
    }
    final first = _day(sorted.first.periodFrom);
    final last = sorted
        .map((b) => _day(b.periodTo))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return first == start && last == cut && days == _days(start, cut) + 1;
  }

  /// What the contract schedules still expect in the months (0532).
  DemoUnbilled _unbilled(String fromMonth, String toMonth) => demoUnbilled(
    schedules: demoContractSchedules(
      leases: sources.leases.leases,
      rentals: sources.rooms.rentals,
      commitments: sources.commitments,
    ),
    commitments: sources.commitments,
    start: _firstDay(fromMonth),
    cut: _lastDay(toMonth),
    today: _day(now),
  );

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _days(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static DateTime _firstDay(String month) =>
      DateTime(int.parse(month.substring(0, 4)), int.parse(month.substring(5)));

  static DateTime _lastDay(String month) => DateTime(
    int.parse(month.substring(0, 4)),
    int.parse(month.substring(5)) + 1,
    0,
  );
}
