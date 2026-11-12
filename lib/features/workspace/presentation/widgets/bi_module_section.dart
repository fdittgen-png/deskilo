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

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_customer_views.dart';
import 'bi_dashboard.dart';
import 'bi_item_views.dart';
import 'bi_overview_views.dart';
import 'bi_purchase_views.dart';
import 'bi_result_views.dart';
import 'bi_sales_views.dart';
import 'bi_toolbar.dart';
import 'bi_vendor_views.dart';
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
    this.action,
    this.rowLabel = _ownLabel,
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

  /// How it is computed. It reads the reader's [AppFormat] (locale and
  /// clock preference), not a bare locale: a time in it follows the
  /// person's clock.
  final List<String> Function(
    BiMeasure m,
    AppLocalizations l10n,
    AppFormat format,
  )
  details;

  /// #2582 — what the card offers beyond reading it (the allocation rules).
  final Widget Function(BuildContext context)? action;

  /// #3294 — the name of one of the module's own rows (a cohort, a level,
  /// a customer's rank); null leaves the row's label.
  final String? Function(BiRow row, AppLocalizations l10n, String locale)
  rowLabel;

  static String? _ownLabel(BiRow row, AppLocalizations l10n, String locale) =>
      null;

  /// [rows], each named by [rowLabel] where it names it.
  List<BiRow> labelled(
    List<BiRow> rows,
    AppLocalizations l10n,
    String locale,
  ) => [
    for (final row in rows)
      BiRow(
        key: row.key,
        label: rowLabel(row, l10n, locale) ?? row.label,
        current: row.current,
        compared: row.compared,
      ),
  ];
}

// The BI table's column renderers: locale-aware (NumberFormat,
// MoneyFormat), not the plain file formatters of lib/core (#2385).
/// A share as a percentage with one decimal; a dash when it is undefined.
String biPercentCell(num? v, String locale, String? currency) => v == null
    ? '—'
    : NumberFormat.decimalPercentPattern(
        locale: locale,
        decimalDigits: 1,
      ).format(v);

SeatCapacityKpi? _seat(BiMeasure m) => m.detail as SeatCapacityKpi?;

FinanceSummaryKpi? _finance(BiMeasure m) => m.detail as FinanceSummaryKpi?;

/// An amount in [currency]; a dash when it is unknown or has no
/// currency — never a default euro (#1924).
String biMoneyCell(num? v, String locale, String? currency) =>
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

/// The views of the registered modules (conformance-tested).
final biModuleViews = <String, BiModuleView>{
  'capacity.seat_utilisation': BiModuleView(
    title: (l10n) => l10n.capacityKpiTitle,
    value: biPercentCell,
    basis: (m, l10n, locale) => switch (_seat(m)) {
      final k? => capacityKpiRatioLine(k, l10n, locale),
      null => '',
    },
    notes: (m, l10n, locale) => switch (_seat(m)) {
      final k? => capacityKpiNotes(k, l10n, locale),
      null => const [],
    },
    details: (m, l10n, format) => switch (_seat(m)) {
      final k? => capacityKpiDetails(k, l10n, format),
      null => const [],
    },
  ),
  'finance.invoiced': BiModuleView(
    title: (l10n) => l10n.biFinanceInvoiced,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_finance(m)) {
      final k? =>
        l10n.biFinanceInvoicedBasis(
              k.invoices,
              biMoneyCell(k.creditNotesMinor, locale, k.currency),
            ),
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, true),
    details: (m, l10n, format) => _financeDetails(m, l10n, format.locale, true),
  ),
  'finance.collected': BiModuleView(
    title: (l10n) => l10n.biFinanceCollected,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown ? '' : switch (_finance(m)) {
      final k? =>
        l10n.biFinanceCollectedBasis(k.matches),
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, false),
    details: (m, l10n, format) => _financeDetails(m, l10n, format.locale, false),
  ),
  ...purchaseModuleViews,
  ...overviewModuleViews,
  ...customerModuleViews,
  ...vendorModuleViews,
  ...salesModuleViews,
  ...itemModuleViews,
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
      // The page's grid spaces the analyses.
      margin: EdgeInsets.zero,
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
                // Another version of the figure: asking again changes nothing.
                KpiIncompatible() => Text(
                  l10n.biIncompatible,
                  key: const ValueKey('bi-incompatible'),
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
        l10n.biRefusedBudget(biGroupBudget),
    ].join(' '),
    key: const ValueKey('bi-refused'),
  );
}

/// The comparison with the period before, after the sign of the change
/// said in words, not by colour.
class _ComparedLine extends StatelessWidget {
  const _ComparedLine({required this.change, required this.text});

  final BiChange change;
  final String text;

  @override
  Widget build(BuildContext context) {
    final direction = KpiTrendDirection.of(
      change.points ?? change.absolute ?? change.relative,
    );
    return Row(
      children: [
        if (direction != null) ...[
          KpiTrendMark(direction),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: Text(text, key: const ValueKey('bi-compared'))),
      ],
    );
  }
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
    final locale = appFormatOf(context).locale;
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
          _ComparedLine(
            change: changeOf(total, agg),
            text: l10n.biComparedLine(
              comparedLabel,
              view.value(compared.value(agg), locale, result.currency),
              biChangeLabel(changeOf(total, agg), l10n, locale, format: amount),
            ),
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
          rows: [...view.labelled(result.groups, l10n, locale), total],
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
            for (final line in view.details(total.current, l10n, appFormatOf(context)))
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
        if (view.action case final action?) action(context),
      ],
    );
  }
}
