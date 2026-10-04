// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The dashboard of one analysis, on screen: its figure with how it moved,
// its evolution over the past periods and where that points, how now
// compares with the past, and what it is made of. It renders
// [BiDashboardContent] — the same content the PDF renders.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../providers/bi_providers.dart';
import '../../providers/workspace_providers.dart';
import 'bi_charts.dart';
import 'bi_dashboard_content.dart';
import 'bi_module_section.dart' show BiModuleView;
import 'bi_share_chart.dart';
import 'bi_toolbar.dart' show biPeriodLabel;

class BiDashboard extends ConsumerWidget {
  const BiDashboard({
    super.key,
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
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final grain = result.period.grain;
    final seriesAsync = ref.watch(
      biModuleSeriesProvider(
        workspace.id,
        module.id,
        grain,
        result.period,
        biSeriesLength(grain),
      ),
    );
    final grouped = module.groupings.contains('level')
        ? ref.watch(
            biModuleResultProvider(
              workspace.id,
              module.id,
              BiQueryContext(
                grain: grain,
                period: BiPeriodRef.fixed(result.period),
                groupBy: 'level',
                sort: BiSort.valueDescending,
              ),
            ),
          )
        : null;
    final invoiced = module.id == 'finance.collected'
        ? ref.watch(
            biModuleResultProvider(
              workspace.id,
              'finance.invoiced',
              BiQueryContext(
                grain: grain,
                period: BiPeriodRef.fixed(result.period),
              ),
            ),
          )
        : null;
    final head = <Widget>[
      Text(
        biPeriodLabel(result.period, l10n, locale),
        key: const ValueKey('bi-result-period'),
        style: theme.textTheme.bodySmall,
      ),
    ];
    final series = seriesAsync.value;
    if (series == null) {
      return Column(
        key: const ValueKey('bi-dashboard'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...head,
          Text(
            view.value(result.total.current.value(module.aggregation), locale, result.currency),
            key: const ValueKey('bi-value'),
            style: theme.textTheme.displaySmall,
          ),
          if (seriesAsync is AsyncError)
            Text(
              l10n?.biUnavailable ?? 'This analysis could not be computed.',
              key: const ValueKey('bi-series-unavailable'),
            )
          else
            const LinearProgressIndicator(key: ValueKey('bi-series-loading')),
        ],
      );
    }
    final interval = biInterval(result.period);
    final content = biDashboardContent(
      module: module,
      view: view,
      result: result,
      series: series,
      extras: BiDashboardExtras(
        groupedByLevel: grouped?.value,
        invoiced: invoiced?.value,
      ),
      l10n: l10n,
      locale: locale,
      from: interval.from,
      to: interval.to,
      now: ref.read(clockProvider).now(),
    );
    return BiDashboardView(content: content);
  }
}

/// Renders [content]; used by the page and by the tests.
class BiDashboardView extends StatelessWidget {
  const BiDashboardView({super.key, required this.content});

  final BiDashboardContent content;

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = content;
    return Column(
      key: const ValueKey('bi-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.period,
          key: const ValueKey('bi-result-period'),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          c.figure,
          key: const ValueKey('bi-value'),
          style: theme.textTheme.displaySmall,
        ),
        Text(c.basis),
        const SizedBox(height: AppSpacing.sm),
        if (c.chips.isEmpty)
          Text(
            c.noComparisonLabel,
            key: const ValueKey('bi-delta-none'),
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final chip in c.chips)
                BiDeltaChip(
                  key: ValueKey('bi-delta-${chip.kind.name}'),
                  direction: chip.direction,
                  label: chip.label,
                ),
            ],
          ),
        if (c.narrative != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(c.narrative!, key: const ValueKey('bi-narrative')),
          ),
        if (c.provisionalNote != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(c.provisionalNote!, style: theme.textTheme.bodySmall),
          ),
        if (c.runRate != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(c.runRate!, key: const ValueKey('bi-run-rate')),
          ),
        _title(context, c.evolutionTitle),
        BiEvolutionChart(
          series: c.series,
          forecast: c.forecast,
          format: c.format,
          periodLabel: c.periodLabel,
          shortLabel: c.shortLabel,
          projectedLabel: c.projectedLabel,
          noDataLabel: c.noDataLabel,
          partialLabel: c.partialLabel,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            c.projectionBasis,
            key: const ValueKey('bi-projection-basis'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (c.projectionNext != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              c.projectionNext!,
              key: const ValueKey('bi-projection-next'),
              style: theme.textTheme.titleSmall,
            ),
          ),
        _title(context, c.compareTitle),
        BiCompareBars(
          bars: [for (final b in c.bars) b.bar],
          format: c.format,
          periodLabel: c.periodLabel,
          kindLabel: c.kindLabel,
          changeLabel: (bar) =>
              c.bars.firstWhere((b) => b.bar == bar).change,
          direction: (bar) =>
              c.bars.firstWhere((b) => b.bar == bar).direction,
          partialLabel: c.partialLabel,
          noDataLabel: c.noDataLabel,
        ),
        for (final comp in c.compositions) ...[
          _title(context, comp.title),
          if (comp.none != null)
            Text(comp.none!, key: const ValueKey('bi-composition-none'))
          else
            BiShareBreakdown(
              shares: comp.shares,
              formatValue: comp.formatValue!,
              formatShare: comp.formatShare!,
              centreValue: comp.centreValue,
              centreLabel: comp.centreLabel,
            ),
        ],
      ],
    );
  }
}
