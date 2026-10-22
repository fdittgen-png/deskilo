// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2582 C1 — the purchase figures on the analytics page: read once per
// workspace and months from `kpi_purchases_summary`, exact to the minor unit,
// a missing amount never read as 0, the payable a stock (compared, never
// summed), the review queue a count that survives a currency mix, every
// card behind the purchaseAnalytics flag and the finance right; and (C2)
// the costs, the capital additions and invoiced less operating costs, the
// book depreciation and what the contracts still expect to be billed.
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/domain/kpi_purchases.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:deskilo/features/workspace/providers/bi_providers.dart';
import 'package:deskilo/features/workspace/providers/bi_purchase_reader.dart';
import 'package:deskilo/features/workspace/providers/kpi_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'purchases.ap_outstanding',
  'purchases.member_reimbursements_due',
  'purchases.pending_reviews',
  'cash.recorded_outflows',
  'purchases.operating_costs',
  'assets.acquisitions',
  'finance.recorded_contribution',
  'assets.book_depreciation',
  'finance.contribution_after_depreciation',
  'purchases.unbilled_commitments',
];

Map<String, dynamic> _row({
  String from = '2026-04',
  String to = '2026-04',
  Object? ap = '400',
  Object? member = '70',
  Object? out = '600',
  String currency = 'EUR',
  List<String> quality = const [],
  List<String> reasons = const [],
}) => {
  'from': from,
  'to': to,
  'currency': currency,
  'ap_outstanding_minor': ap,
  'member_due_minor': member,
  'pending_count': 1,
  'pending_minor': '500',
  'outflows_minor': out,
  'outflows': 1,
  'quality': quality,
  'reasons': reasons,
  'computed_at': '2026-05-02T10:00:00Z',
};

/// April 2026 as pgTAP 243 reads it; March 1 000 owed, 50 paid out.
class _Purchases implements PurchaseKpiRepository {
  final calls = <(String, String)>[];

  @override
  Future<PurchaseSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    calls.add((fromMonth, toMonth));
    return purchaseSummaryFromJson(
      fromMonth == '2026-03'
          ? _row(from: fromMonth, to: toMonth, ap: '1000', out: '50')
          : _row(from: fromMonth, to: toMonth),
    );
  }
}

void main() {
  test('the four cards exist only with the flag and the finance right', () {
    const rights = {
      WorkspacePermission.viewAnalytics,
      WorkspacePermission.viewFinances,
    };
    final shown = visibleBiModules({
      WorkspaceFeature.purchaseAnalytics,
    }, rights).map((m) => m.id);
    expect(shown, containsAll(_ids));
    expect(
      visibleBiModules(const {}, rights).map((m) => m.id),
      isNot(contains('purchases.ap_outstanding')),
    );
    expect(
      visibleBiModules(
        {WorkspaceFeature.purchaseAnalytics},
        {WorkspacePermission.viewAnalytics},
      ).map((m) => m.id),
      isNot(contains('purchases.ap_outstanding')),
    );
    for (final id in _ids) {
      expect(biModuleViews.containsKey(id), isTrue, reason: id);
    }
  });

  test('an amount that cannot travel exactly is unknown, never 0', () {
    final k = purchaseSummaryFromJson(_row(ap: '12.5'));
    expect(k.apOutstandingMinor, isNull);
    expect(k.quality, contains(KpiQuality.unavailable));
    expect(k.reasons, contains('amount_not_exact'));
  });

  test('the review queue is a count a currency mix leaves exact', () {
    final mixed = purchaseSummaryFromJson(
      _row(quality: ['unavailable'], reasons: ['currency_mix']),
    );
    expect(
      purchaseMeasure(mixed, 'purchases.pending_reviews').unknown,
      isFalse,
    );
    expect(purchaseMeasure(mixed, 'purchases.pending_reviews').numerator, 1);
    expect(
      purchaseMeasure(mixed, 'purchases.ap_outstanding').unknown,
      isTrue,
      reason: 'the amounts are not summed across currencies',
    );
  });

  test('April against March: the payable compared as a stock, one read per '
      'month', () async {
    final purchases = _Purchases();
    final container = ProviderContainer(
      overrides: [
        purchaseKpiRepositoryProvider.overrideWithValue(purchases),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 5, 2))),
      ],
    );
    addTearDown(container.dispose);
    const context = BiQueryContext(
      period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2026, 4)),
      comparison: BiComparison.previousPeriod,
    );
    for (final id in _ids) {
      final provider = biModuleResultProvider('ws-1', id, context);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
    }
    final ap = await container.read(
      biModuleResultProvider(
        'ws-1',
        'purchases.ap_outstanding',
        context,
      ).future,
    );
    expect(ap.total.current.value(KpiAggregation.lastAtCutoff), 400);
    expect(ap.total.compared?.value(KpiAggregation.lastAtCutoff), 1000);
    expect(ap.currency, 'EUR');
    final out = await container.read(
      biModuleResultProvider('ws-1', 'cash.recorded_outflows', context).future,
    );
    expect(out.total.current.value(KpiAggregation.sum), 600);
    final pending = await container.read(
      biModuleResultProvider(
        'ws-1',
        'purchases.pending_reviews',
        context,
      ).future,
    );
    expect(pending.total.current.numerator, 1);
    expect(pending.currency, isNull, reason: 'a count has no currency');
    expect(purchases.calls.toSet(), {
      ('2026-04', '2026-04'),
      ('2026-03', '2026-03'),
    }, reason: 'one summary per month, shared by the four cards');
  });

  test('C2: invoiced less operating costs, and the capital additions never '
      'a cost; a register switched off is unknown, never 0', () async {
    final costs = _Costs();
    final container = ProviderContainer(
      overrides: [
        costKpiRepositoryProvider.overrideWithValue(costs),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 5, 2))),
      ],
    );
    addTearDown(container.dispose);
    const context = BiQueryContext(
      period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2026, 3)),
    );
    Future<num?> value(String id) async {
      final provider = biModuleResultProvider('ws-1', id, context);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final r = await container.read(provider.future);
      return r.total.current.value(KpiAggregation.sum);
    }

    expect(await value('purchases.operating_costs'), 1100);
    expect(await value('finance.recorded_contribution'), 900);
    expect(await value('assets.acquisitions'), 1200);
    final off = costSummaryFromJson(_costRow(acquisitions: null));
    expect(costMeasure(off, 'assets.acquisitions').unknown, isTrue);
    expect(costMeasure(off, 'purchases.operating_costs').unknown, isFalse);
  });

  test('C2: after book depreciation only when the depreciation is known; '
      'the contracts still to be billed, overdue and upcoming apart', () {
    final known = costSummaryFromJson(_costRow());
    expect(costMeasure(known, 'assets.book_depreciation').numerator, 20);
    expect(
      costMeasure(known, 'finance.contribution_after_depreciation').numerator,
      880,
    );
    expect(
      costMeasure(known, 'purchases.unbilled_commitments').numerator,
      2400,
    );
    expect(known.unbilledOverdueMinor, 1400);
    expect(known.unbilledUpcomingMinor, 1000);

    final missing = costSummaryFromJson(
      _costRow(depreciation: null, after: null, unbilled: null),
    );
    for (final id in const [
      'assets.book_depreciation',
      'finance.contribution_after_depreciation',
      'purchases.unbilled_commitments',
    ]) {
      expect(costMeasure(missing, id).unknown, isTrue, reason: id);
    }
    expect(
      costMeasure(missing, 'finance.recorded_contribution').numerator,
      900,
      reason: 'the figure without depreciation keeps its own name',
    );
    final inexact = costSummaryFromJson(_costRow(depreciation: '2.5'));
    expect(inexact.bookDepreciationMinor, isNull);
    expect(inexact.reasons, contains('amount_not_exact'));
  });
}

Map<String, Object?> _costRow({
  Object? acquisitions = '1200',
  Object? depreciation = '20',
  Object? after = '880',
  Object? unbilled = '2400',
}) => {
  'from': '2026-03',
  'to': '2026-03',
  'currency': 'EUR',
  'operating_costs_minor': '1100',
  'acquisitions_minor': acquisitions,
  'net_sales_minor': '2000',
  'contribution_minor': '900',
  'unresolved_lines': 1,
  'unqualified_lines': 0,
  'book_depreciation_minor': depreciation,
  'after_depreciation_minor': after,
  'unbilled_minor': unbilled,
  'unbilled_overdue_minor': unbilled == null ? null : '1400',
  'unbilled_upcoming_minor': unbilled == null ? null : '1000',
  'quality': const <String>[],
  'reasons': const ['unresolved_lines'],
  'computed_at': '2026-05-02T10:00:00Z',
};

/// March 2026 as pgTAP 244 reads it.
class _Costs implements CostKpiRepository {
  @override
  Future<CostSummaryKpi> summary(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async => costSummaryFromJson(_costRow());
}
