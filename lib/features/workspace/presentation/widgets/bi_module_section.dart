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
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_result_views.dart';
import 'bi_toolbar.dart';
import 'capacity_kpi_card.dart';
import 'capacity_evidence.dart';

/// How a module's figures read. One per registered module.
class BiModuleView {
  const BiModuleView({
    required this.title,
    required this.value,
    required this.basis,
    required this.notes,
    required this.details,
  });

  final String Function(AppLocalizations? l10n) title;

  /// The figure, or a dash when it is undefined.
  final String Function(num? value, String locale, String? currency) value;

  /// The figure's two sides ("25 of 100 seat-hours reserved").
  final String Function(BiMeasure m, AppLocalizations? l10n, String locale)
  basis;

  /// What the current figure cannot know or does not count.
  final List<String> Function(
    BiMeasure m,
    AppLocalizations? l10n,
    String locale,
  )
  notes;

  /// How it is computed.
  final List<String> Function(
    BiMeasure m,
    AppLocalizations? l10n,
    String locale,
  )
  details;
}

String _percent(num? v, String locale, String? currency) => v == null
    ? '—'
    : NumberFormat.decimalPercentPattern(
        locale: locale,
        decimalDigits: 1,
      ).format(v);

SeatCapacityKpi? _seat(BiMeasure m) => m.detail as SeatCapacityKpi?;

FinanceSummaryKpi? _finance(BiMeasure m) => m.detail as FinanceSummaryKpi?;

/// An amount in [currency]; a dash when it is unknown or has no
/// currency — never a default euro (#1924).
String _money(num? v, String locale, String? currency) =>
    v == null || currency == null || currency.isEmpty
    ? '—'
    : MoneyFormat(currency, locale: locale).formatMinor(v.toInt());

List<String> _financeNotes(
  BiMeasure m,
  AppLocalizations? l10n,
  bool invoiced,
) => [
  if (m.reasons.contains('currency_mix'))
    l10n?.biFinanceCurrencyMix ??
        'This period holds amounts in another currency; amounts in '
            'different currencies are not added, so none is shown.',
  if (m.reasons.contains('amount_not_exact'))
    l10n?.biFinanceNotExact ??
        'An amount is too large to show exactly, so it is not shown.',
  if (m.reasons.contains('period_not_over'))
    l10n?.biFinancePartial ??
        'The period is not over: these figures will still change.',
  if (m.quality.contains(KpiQuality.knownZero))
    invoiced
        ? l10n?.biFinanceInvoicedZero ?? 'Measured: nothing was invoiced.'
        : l10n?.biFinanceCollectedZero ?? 'Measured: nothing was collected.',
];

List<String> _financeDetails(
  BiMeasure m,
  AppLocalizations? l10n,
  String locale,
  bool invoiced,
) {
  final k = _finance(m);
  if (k == null) return const [];
  final date = DateFormat.yMd(locale);
  return [
    if (invoiced)
      l10n?.biFinanceInvoicedDefinition ??
          'Invoices of these months, voided ones and settlements left out '
              '(a settlement regroups invoices already counted); positive '
              'totals only.'
    else
      l10n?.biFinanceCollectedDefinition ??
          'Payments matched to invoices, by the month of the match on the '
              'workspace clock.',
    l10n?.biFinanceNotProfit ??
        'Not a profit: no cost is in this figure, and the two figures are '
            'not subtracted from each other.',
    l10n?.biFinanceSameAsReport ??
        'The same rules as the workspace status report, computed once on '
            'the server.',
    if (k.lastChangeAt case final last?)
      l10n?.biFinanceLastChange(date.format(last.toLocal())) ??
          'Last change to the source: ${date.format(last.toLocal())}',
    l10n?.biFinanceComputed(date.format(k.computedAt.toLocal())) ??
        'Computed ${date.format(k.computedAt.toLocal())}',
  ];
}

/// The views of the registered modules (conformance-tested).
final biModuleViews = <String, BiModuleView>{
  'capacity.seat_utilisation': BiModuleView(
    title: (l10n) => l10n?.capacityKpiTitle ?? 'Seat utilisation',
    value: _percent,
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
    title: (l10n) => l10n?.biFinanceInvoiced ?? 'Invoiced',
    value: _money,
    basis: (m, l10n, locale) => switch (_finance(m)) {
      final k? =>
        l10n?.biFinanceInvoicedBasis(
              '${k.invoices}',
              _money(k.creditNotesMinor, locale, k.currency),
            ) ??
            'From ${k.invoices} invoices; credit notes '
                '${_money(k.creditNotesMinor, locale, k.currency)}, shown '
                'apart',
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, true),
    details: (m, l10n, locale) => _financeDetails(m, l10n, locale, true),
  ),
  'finance.collected': BiModuleView(
    title: (l10n) => l10n?.biFinanceCollected ?? 'Collected',
    value: _money,
    basis: (m, l10n, locale) => switch (_finance(m)) {
      final k? =>
        l10n?.biFinanceCollectedBasis('${k.matches}') ??
            'From ${k.matches} payments matched to invoices',
      null => '',
    },
    notes: (m, l10n, locale) => _financeNotes(m, l10n, false),
    details: (m, l10n, locale) => _financeDetails(m, l10n, locale, false),
  ),
};

/// The change, worded: "+3.2 pp" for a ratio; for an amount the
/// difference in its unit ([format]) and the relative change beside it,
/// "+150,00 € (+12.5 %)"; "—" when it is undefined.
String biChangeLabel(
  BiChange c,
  AppLocalizations? l10n,
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
    return l10n?.biChangePoints(s) ?? '$s pp';
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
    final l10n = AppLocalizations.of(context);
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
                  tooltip: l10n?.biRefresh ?? 'Refresh data',
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
                  l10n?.biForbidden ??
                      'You may not read this analysis in this workspace.',
                  key: const ValueKey('bi-forbidden'),
                ),
                _ => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n?.biUnavailable ??
                          'This analysis could not be computed.',
                      key: const ValueKey('bi-unavailable'),
                    ),
                    TextButton(
                      key: const ValueKey('bi-retry'),
                      onPressed: () => ref.invalidate(provider),
                      child: Text(l10n?.capacityKpiRetry ?? 'Try again'),
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
    AppLocalizations? l10n,
    Set<BiUnsupported> reasons,
    bool budget,
  ) => Text(
    [
      if (reasons.contains(BiUnsupported.grain))
        l10n?.biRefusedGrain ??
            'This analysis is not offered for that period length.',
      if (reasons.contains(BiUnsupported.comparison))
        l10n?.biRefusedComparison ??
            'This analysis cannot make that comparison.',
      if (reasons.contains(BiUnsupported.grouping))
        l10n?.biRefusedGrouping ?? 'This analysis cannot be grouped that way.',
      if (budget)
        l10n?.biRefusedBudget('$biGroupBudget') ??
            'There are more than $biGroupBudget groups; choose no grouping.',
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
    final l10n = AppLocalizations.of(context);
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
        l10n?.biComparedNotRecorded(comparedLabel, since(compared)) ??
            '$comparedLabel was not recorded (history begins ${since(compared)}); '
                'there is no comparison.'
      else if (compared != null &&
          compared.quality.contains(KpiQuality.partial))
        l10n?.biComparedPartial(comparedLabel) ??
            '$comparedLabel is only partly recorded.',
      if (compared != null && [...total.current.quality, ...compared.quality]
          .any((q) => q == KpiQuality.partial || q == KpiQuality.stale))
        l10n?.biComparisonUnqualified ??
            'Change unavailable: one period has partial or out-of-date data.',
      if (exposureDiffers(total))
        l10n?.biExposureDiffers ??
            'The two periods do not offer the same base; the ratio accounts '
                'for it, the hours do not compare directly.',
    ];
    final drill = module.drill;
    final mayDrill =
        drill != null &&
        ref.watch(myPermissionsProvider).contains(drill.permission);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            l10n?.biComparedLine(
                  comparedLabel,
                  view.value(compared.value(agg), locale, result.currency),
                  biChangeLabel(
                    changeOf(total, agg),
                    l10n,
                    locale,
                    format: amount,
                  ),
                ) ??
                '$comparedLabel: ${view.value(compared.value(agg), locale, result.currency)} '
                    '(${biChangeLabel(changeOf(total, agg), l10n, locale, format: amount)})',
            key: const ValueKey('bi-compared'),
          ),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(note, style: small),
          ),
        const SizedBox(height: AppSpacing.sm),
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
          title: Text(l10n?.capacityKpiExplain ?? 'How is this computed?'),
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
          mayDrill
              ? TextButton.icon(
                  key: const ValueKey('bi-drill'),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n?.biOpenSource ?? 'Open the source'),
                  // push: Back returns to this page and its address.
                  onPressed: () => context.push(drill.route),
                )
              : Text(
                  l10n?.biSourceRestricted ??
                      'The source records are shown only to those who '
                          'manage them.',
                  key: const ValueKey('bi-drill-restricted'),
                  style: small,
                ),
      ],
    );
  }
}
