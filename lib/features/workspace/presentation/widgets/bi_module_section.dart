// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — one module on the Web-BI page: its own loading, refusal and
// failure, the figure, the comparison, what the data cannot know, the
// rows as a table or a chart (the SAME rows, the same formatted values),
// how it is computed and where it comes from. A section that fails
// fails alone; an undefined figure is a dash and a reason, never a 0.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';
import '../../domain/kpi_purchases.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_dashboard.dart';
import 'bi_result_views.dart';
import 'bi_toolbar.dart';
import 'capacity_evidence.dart';
import 'capacity_kpi_card.dart';

/// How a module's figures read. One per registered module.
class BiModuleView {
  const BiModuleView({
    required this.title,
    required this.value,
    required this.basis,
    required this.notes,
    required this.details,
  });

  final String Function(AppLocalizations l10n) title;

  /// The figure, or a dash when it is undefined.
  final String Function(num? value, String locale, String? currency) value;

  /// The figure's two sides ("25 of 100 seat-hours reserved").
  final String Function(BiMeasure m, AppLocalizations l10n, String locale)
  basis;

  /// What the current figure cannot know or does not count.
  final List<String> Function(
    BiMeasure m,
    AppLocalizations l10n,
    String locale,
  )
  notes;

  /// How it is computed.
  final List<String> Function(
    BiMeasure m,
    AppLocalizations l10n,
    String locale,
  )
  details;
}

// The BI table's column renderers: locale-aware (NumberFormat,
// MoneyFormat), not the plain file formatters of lib/core (#2385).
String _percentCell(num? v, String locale, String? currency) => v == null
    ? '—'
    : NumberFormat.decimalPercentPattern(
        locale: locale,
        decimalDigits: 1,
      ).format(v);

SeatCapacityKpi? _seat(BiMeasure m) => m.detail as SeatCapacityKpi?;

FinanceSummaryKpi? _finance(BiMeasure m) => m.detail as FinanceSummaryKpi?;

/// An amount in [currency]; a dash when it is unknown or has no
/// currency — never a default euro (#1924).
String _moneyCell(num? v, String locale, String? currency) =>
    v == null || currency == null || currency.isEmpty
    ? '—'
    : MoneyFormat(currency, locale: locale).formatMinor(v.toInt());

List<String> _financeNotes(
  BiMeasure m,
  AppLocalizations l10n,
  bool invoiced,
) => [
  if (m.reasons.contains('currency_mix'))
    l10n.biFinanceCurrencyMix,
  if (m.reasons.contains('amount_not_exact'))
    l10n.biFinanceNotExact,
  if (m.reasons.contains('period_not_over'))
    l10n.biFinancePartial,
  if (m.quality.contains(KpiQuality.knownZero))
    if (invoiced) l10n.biFinanceInvoicedZero else l10n.biFinanceCollectedZero,
];

List<String> _financeDetails(
  BiMeasure m,
  AppLocalizations l10n,
  String locale,
  bool invoiced,
) {
  final k = _finance(m);
  if (k == null) return const [];
  final date = DateFormat.yMd(locale);
  return [
    if (invoiced)
      l10n.biFinanceInvoicedDefinition
    else
      l10n.biFinanceCollectedDefinition,
    l10n.biFinanceNotProfit,
    l10n.biFinanceSameAsReport,
    if (k.lastChangeAt case final last?)
      l10n.biFinanceLastChange(date.format(WorkspaceTime.wall(last))),
    l10n.biFinanceComputed(date.format(WorkspaceTime.wall(k.computedAt))),
  ];
}

// #2582 — a count of documents, in no currency.
String _countCell(num? v, String locale, String? currency) =>
    v == null ? '—' : NumberFormat.decimalPattern(locale).format(v);

PurchaseSummaryKpi? _purchase(BiMeasure m) => m.detail as PurchaseSummaryKpi?;

/// #2582 — a purchase card: its figure, what it cannot know, and how it is
/// computed.
BiModuleView _purchaseView(
  String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n) definition, {
  bool count = false,
  String Function(PurchaseSummaryKpi k, AppLocalizations l10n, String locale)?
  basis,
  String Function(AppLocalizations l10n)? always,
}) => BiModuleView(
  title: title,
  value: count ? _countCell : _moneyCell,
  basis: (m, l10n, locale) => switch (_purchase(m)) {
    final k? when basis != null && !m.unknown => basis(k, l10n, locale),
    _ => '',
  },
  notes: (m, l10n, locale) => [
    if (m.reasons.contains('currency_mix') && !count) l10n.biFinanceCurrencyMix,
    if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
    if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
    if (count && m.reasons.contains('current_queue'))
      l10n.biPurchasesCurrentQueue,
    if (always != null) always(l10n),
  ],
  details: (m, l10n, locale) => [
    definition(l10n),
    if (_purchase(m) case final k?)
      l10n.biFinanceComputed(
        DateFormat.yMd(locale).format(WorkspaceTime.wall(k.computedAt)),
      ),
  ],
);

/// The views of the registered modules (conformance-tested).
final biModuleViews = <String, BiModuleView>{
  'capacity.seat_utilisation': BiModuleView(
    title: (l10n) => l10n.capacityKpiTitle,
    value: _percentCell,
    basis: (m, l10n, locale) => switch (_seat(m)) {
      final k? => capacityKpiRatioLine(k, l10n, locale),
      null => '',
    },
    notes: (m, l10n, locale) => switch (_seat(m)) {
      final k? => capacityKpiNotes(k, l10n, locale),
      null => const [],
    },
    details: (m, l10n, locale) => switch (_seat(m)) {
      final k? => capacityKpiDetails(k, l10n, locale),
      null => const [],
    },
  ),
  'finance.invoiced': BiModuleView(
    title: (l10n) => l10n.biFinanceInvoiced,
    value: _moneyCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_finance(m)) {
      final k? =>
        l10n.biFinanceInvoicedBasis(
              '${k.invoices}',
              _moneyCell(k.creditNotesMinor, locale, k.currency),
            ),
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, true),
    details: (m, l10n, locale) => _financeDetails(m, l10n, locale, true),
  ),
  'finance.collected': BiModuleView(
    title: (l10n) => l10n.biFinanceCollected,
    value: _moneyCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_finance(m)) {
      final k? =>
        l10n.biFinanceCollectedBasis('${k.matches}'),
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, false),
    details: (m, l10n, locale) => _financeDetails(m, l10n, locale, false),
  ),
  'purchases.ap_outstanding': _purchaseView(
    (l10n) => l10n.biPurchasesApTitle,
    (l10n) => l10n.biPurchasesApDefinition,
  ),
  'purchases.member_reimbursements_due': _purchaseView(
    (l10n) => l10n.biPurchasesMemberDueTitle,
    (l10n) => l10n.biPurchasesMemberDueDefinition,
  ),
  'purchases.pending_reviews': _purchaseView(
    (l10n) => l10n.biPurchasesPendingTitle,
    (l10n) => l10n.biPurchasesPendingDefinition,
    count: true,
    basis: (k, l10n, locale) =>
        l10n.biPurchasesPendingBasis(_moneyCell(k.pendingMinor, locale, k.currency)),
  ),
  'cash.recorded_outflows': _purchaseView(
    (l10n) => l10n.biCashOutflowsTitle,
    (l10n) => l10n.biCashOutflowsDefinition,
    basis: (k, l10n, locale) => l10n.biCashOutflowsBasis('${k.outflows}'),
    always: (l10n) => l10n.biCashNotBankBalance,
  ),
};

/// The change, worded: "+3.2 pp" for a ratio; for an amount the
/// difference in its unit ([format]) and the relative change beside it,
/// "+150,00 € (+12.5 %)"; "—" when it is undefined.
String biChangeLabel(
  BiChange c,
  AppLocalizations l10n,
  String locale, {
  String Function(num value)? format,
}) {
  String sign(num v) => v > 0 ? '+' : '';
  final one = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 1,
  );
  final percent = NumberFormat.decimalPercentPattern(
    locale: locale,
    decimalDigits: 1,
  );
  if (c.points case final p?) {
    final s = '${sign(p)}${one.format(p)}';
    return l10n.biChangePoints(s);
  }
  final relative = c.relative == null
      ? null
      : '${sign(c.relative!)}${percent.format(c.relative)}';
  if (c.absolute case final a?) {
    final absolute = '${sign(a)}${format == null ? one.format(a) : format(a)}';
    return relative == null ? absolute : '$absolute ($relative)';
  }
  return relative ?? '—';
}

class BiModuleSection extends ConsumerWidget {
  const BiModuleSection({super.key, required this.module, required this.query});

  final BiModule module;
  final BiQueryContext query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final view = biModuleViews[module.id];
    if (workspace == null || view == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unsupported = module.unsupported(query);
    final provider = biModuleResultProvider(workspace.id, module.id, query);
    // An unsupported context is refused HERE, before any read.
    final result = unsupported.isEmpty ? ref.watch(provider) : null;
    return Card(
      key: ValueKey('bi-module-${module.id}'),
      margin: AppSpacing.mdAll,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(view.title(l10n), style: theme.textTheme.titleMedium)),
              if (unsupported.isEmpty)
                IconButton(
                  key: const ValueKey('bi-refresh'),
                  tooltip: l10n.biRefresh,
                  onPressed: result is AsyncLoading ? null : () => ref.invalidate(provider),
                  icon: const Icon(Icons.refresh),
                ),
            ]),
            switch (result) {
              null => _refusal(l10n, unsupported, false),
              AsyncData(:final value) => _Result(
                module: module,
                view: view,
                query: query,
                result: value,
              ),
              AsyncError(:final error) => switch (error) {
                BiRefused(:final reasons, :final groupBudgetExceeded) =>
                  _refusal(l10n, reasons, groupBudgetExceeded),
                KpiForbidden() => Text(
                  l10n.biForbidden,
                  key: const ValueKey('bi-forbidden'),
                ),
                _ => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.biUnavailable,
                      key: const ValueKey('bi-unavailable'),
                    ),
                    TextButton(
                      key: const ValueKey('bi-retry'),
                      onPressed: () => ref.invalidate(provider),
                      child: Text(l10n.capacityKpiRetry),
                    ),
                  ],
                ),
              },
              _ => const LoadingView(),
            },
          ],
        ),
      ),
    );
  }

  Widget _refusal(
    AppLocalizations l10n,
    Set<BiUnsupported> reasons,
    bool budget,
  ) => Text(
    [
      if (reasons.contains(BiUnsupported.grain))
        l10n.biRefusedGrain,
      if (reasons.contains(BiUnsupported.comparison))
        l10n.biRefusedComparison,
      if (reasons.contains(BiUnsupported.grouping))
        l10n.biRefusedGrouping,
      if (budget)
        l10n.biRefusedBudget('$biGroupBudget'),
    ].join(' '),
    key: const ValueKey('bi-refused'),
  );
}

class _Result extends ConsumerWidget {
  const _Result({
    required this.module,
    required this.view,
    required this.query,
    required this.result,
  });

  final BiModule module;
  final BiModuleView view;
  final BiQueryContext query;
  final BiResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final agg = module.aggregation;
    final total = result.total;
    final comparedPeriod = result.comparedPeriod;
    final compared = total.compared;
    final small = theme.textTheme.bodySmall;
    String amount(num v) => view.value(v, locale, result.currency);
    String since(BiMeasure m) => m.historySince == null
        ? ''
        : DateFormat.yMMMd(locale).format(WorkspaceTime.wall(m.historySince!));
    final comparedLabel = comparedPeriod == null
        ? ''
        : biPeriodLabel(comparedPeriod, l10n, locale);

    final notes = <String>[
      ...view.notes(total.current, l10n, locale),
      if (compared != null && compared.quality.contains(KpiQuality.notRecorded))
        l10n.biComparedNotRecorded(comparedLabel, since(compared))
      else if (compared != null &&
          compared.quality.contains(KpiQuality.partial))
        l10n.biComparedPartial(comparedLabel),
      if (compared != null && [...total.current.quality, ...compared.quality]
          .any((q) => q == KpiQuality.partial || q == KpiQuality.stale))
        l10n.biComparisonUnqualified,
      if (exposureDiffers(total))
        l10n.biExposureDiffers,
    ];
    final drill = module.drill;
    final mayDrill =
        drill != null &&
        ref.watch(myPermissionsProvider).contains(drill.permission);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (query.view == BiView.dashboard)
          BiDashboard(module: module, view: view, query: query, result: result)
        else ...[
        Text(
          biPeriodLabel(result.period, l10n, locale),
          key: const ValueKey('bi-result-period'),
          style: small,
        ),
        Text(
          view.value(total.current.value(agg), locale, result.currency),
          key: const ValueKey('bi-value'),
          style: theme.textTheme.headlineMedium,
        ),
        if (total.current.detail case final SeatCapacityKpi k)
          CapacityEvidence(kpi: k),
        Text(view.basis(total.current, l10n, locale)),
        if (comparedPeriod != null && compared != null)
          Text(
            l10n.biComparedLine(
                  comparedLabel,
                  view.value(compared.value(agg), locale, result.currency),
                  biChangeLabel(
                    changeOf(total, agg),
                    l10n,
                    locale,
                    format: amount,
                  ),
                ),
            key: const ValueKey('bi-compared'),
          ),
        ],
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: small),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (query.view != BiView.dashboard)
        BiRows(
          rows: [...result.groups, total],
          view: query.view,
          aggregation: agg,
          format: (v) => view.value(v, locale, result.currency),
          change: (row) =>
              biChangeLabel(changeOf(row, agg), l10n, locale, format: amount),
          comparedLabel: comparedPeriod == null ? null : comparedLabel,
          groupHeader: query.groupBy == null
              ? null
              : biDimensionName(l10n, query.groupBy!),
        ),
        ExpansionTile(
          key: const ValueKey('bi-explain'),
          tilePadding: EdgeInsets.zero,
          title: Text(l10n.capacityKpiExplain),
          children: [
            for (final line in view.details(total.current, l10n, locale))
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(line, style: small),
                ),
              ),
          ],
        ),
        if (drill != null)
          if (mayDrill) TextButton.icon(
                  key: const ValueKey('bi-drill'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.biOpenSource),
                  // push: Back returns to this page and its address.
                  onPressed: () => context.push(drill.target(result.period)),
                ) else Text(
                  l10n.biSourceRestricted,
                  key: const ValueKey('bi-drill-restricted'),
                  style: small,
                ),
      ],
    );
  }
}
