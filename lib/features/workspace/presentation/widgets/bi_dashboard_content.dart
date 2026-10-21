// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What one analysis' dashboard says, as plain content: strings and numbers,
// no widgets. The dashboard on screen and the PDF both render THIS, so the
// report is the screen on paper and the two cannot disagree. Every figure
// comes from [bi_analysis.dart] / [bi_composition.dart] over the module's
// own answers.
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_analysis.dart';
import '../../domain/bi_composition.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_content.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';
import 'bi_module_section.dart' show BiModuleView, biChangeLabel;
import 'bi_toolbar.dart' show biPeriodLabel;

export '../../domain/bi_report_content.dart';

/// The short axis label of [p]: "Oct", "Q3", "2026".
String _biShortPeriodLabel(BiPeriod p, String locale) => switch (p.grain) {
  BiGrain.month => DateFormat.MMM(locale).format(DateTime(p.year, p.index)),
  BiGrain.quarter => 'Q${p.index}',
  BiGrain.year => '${p.year}',
};

/// The extra reads a composition needs, already awaited.
class BiDashboardExtras {
  const BiDashboardExtras({this.groupedByLevel, this.invoiced});

  /// The module's result grouped by level (seat time).
  final BiResult? groupedByLevel;

  /// The invoiced figure of the same period (for the collection).
  final BiResult? invoiced;
}

/// Builds the content of [module]'s dashboard.
BiDashboardContent biDashboardContent({
  required BiModule module,
  required BiModuleView view,
  required BiResult result,
  required BiSeries series,
  required BiDashboardExtras extras,
  required AppLocalizations l10n,
  required String locale,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) => _DashboardBuilder(
  module: module,
  view: view,
  result: result,
  series: series,
  extras: extras,
  l10n: l10n,
  locale: locale,
  from: from,
  to: to,
  now: now,
).build();

/// One dashboard's build: the shared reads (run rate, the basis the
/// present is judged by) once, then one method per block of content.
class _DashboardBuilder {
  _DashboardBuilder({
    required this.module,
    required this.view,
    required this.result,
    required this.series,
    required this.extras,
    required this.l10n,
    required this.locale,
    required this.from,
    required this.to,
    required this.now,
  }) : agg = module.aggregation {
    final current = series.current;
    rate = runRateOf(current, from: from, to: to, now: now, aggregation: agg);
    // What the present is judged by: a finished figure, or — for a running
    // period — its pace (additive) or its figure so far (a ratio), which is
    // marked provisional wherever it is used.
    basis = !current.partial
        ? current.value
        : agg == KpiAggregation.sum
        ? rate?.projected
        : current.value;
    provisional = current.partial && basis != null;
  }

  static const _need = 4;

  final BiModule module;
  final BiModuleView view;
  final BiResult result;
  final BiSeries series;
  final BiDashboardExtras extras;
  final AppLocalizations l10n;
  final String locale;
  final DateTime from;
  final DateTime to;
  final DateTime now;
  final KpiAggregation agg;
  late final BiRunRate? rate;
  late final num? basis;
  late final bool provisional;

  String format(num v) => view.value(v, locale, result.currency);
  String periodLabel(BiPeriod p) => biPeriodLabel(p, l10n, locale);
  String changeText(BiChange c) =>
      biChangeLabel(c, l10n, locale, format: format);
  String kindLabel(BiBarKind k) => switch (k) {
    BiBarKind.current => l10n.biKindCurrent,
    BiBarKind.previous => l10n.biKindPrevious,
    BiBarKind.yearAgo => l10n.biKindYearAgo,
  };

  BiChange against(BiSeriesPoint? past) =>
      past == null || !past.complete
      ? const BiChange()
      : changeBetween(basis, past.value, agg);

  late final percent = NumberFormat.decimalPercentPattern(
    locale: locale,
    decimalDigits: 1,
  );
  String share(double s) => percent.format(s);
  String hours(num v) =>
      '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1).format(v)} h';

  List<BiChipContent> chips() => [
    for (final (kind, past) in [
      (BiBarKind.previous, series.previous),
      (BiBarKind.yearAgo, series.yearAgo),
    ])
      if (past != null && past.complete)
        BiChipContent(
          kind: kind,
          direction: directionOf(against(past)),
          label:
              '${provisional ? '≈ ' : ''}${changeText(against(past))} '
              '${kind == BiBarKind.previous ? (l10n.biVsPrevious) : (l10n.biVsYearAgo)}',
        ),
  ];

  String? narrative() {
    final lead = [
      for (final (kind, past) in [
        (BiBarKind.previous, series.previous),
        (BiBarKind.yearAgo, series.yearAgo),
      ])
        if (past != null && past.complete && !against(past).undefined)
          (kind, against(past)),
    ].firstOrNull;
    if (lead == null) return null;
    final label = kindLabel(lead.$1).toLowerCase();
    final words = changeText(lead.$2);
    return switch (directionOf(lead.$2)) {
      BiDirection.up => l10n.biNarrativeUp(label, words),
      BiDirection.down => l10n.biNarrativeDown(label, words),
      _ => l10n.biNarrativeFlat(label),
    };
  }

  List<BiBarContent> bars() => [
    for (final bar in comparisonBars(series))
      BiBarContent(
        bar: bar,
        change: bar.kind == BiBarKind.current || bar.partial
            ? null
            : (() {
                final c = against(
                  BiSeriesPoint(period: bar.period, value: bar.value),
                );
                return c.undefined
                    ? null
                    : '${provisional ? '≈ ' : ''}${changeText(c)}';
              })(),
        direction: bar.kind == BiBarKind.current || bar.partial
            ? BiDirection.unknown
            : directionOf(
                against(BiSeriesPoint(period: bar.period, value: bar.value)),
              ),
      ),
  ];

  List<BiCompositionContent> compositions() {
    final detail = result.total.current.detail;
    if (detail is SeatCapacityKpi) return _seatCompositions(detail);
    if (module.id == 'finance.collected') {
      final inv = extras.invoiced?.total.current.detail;
      if (inv is FinanceSummaryKpi && detail is FinanceSummaryKpi) {
        return [_collectionComposition(inv, detail)];
      }
    }
    return const [];
  }

  List<BiCompositionContent> _seatCompositions(SeatCapacityKpi detail) {
    final out = <BiCompositionContent>[];
    final labels = SeatTimeLabels(
      reserved: l10n.biSeatReserved,
      free: l10n.biSeatFree,
      closed: l10n.biSeatClosed,
    );
    final parts = seatTimeComposition(detail, labels);
    if (parts != null) {
      final reserved = parts.where((p) => p.key == 'reserved').firstOrNull;
      out.add(
        BiCompositionContent(
          title: l10n.biCompositionTitle,
          shares: parts,
          formatValue: hours,
          formatShare: share,
          centreValue: share(reserved?.share ?? 0),
          centreLabel: '${labels.reserved} · ${l10n.biSeatCentre}',
        ),
      );
    }
    final rows = extras.groupedByLevel?.groups;
    final byLevel = rows == null
        ? null
        : sharesOf(
            rows,
            labelOf: (r) => r.label ?? r.key,
            otherLabel: l10n.biRemainder,
          );
    if (byLevel != null) {
      out.add(
        BiCompositionContent(
          title: l10n.biShareByLevel,
          shares: byLevel,
          formatValue: hours,
          formatShare: share,
          centreValue: hours(byLevel.fold<num>(0, (a, s) => a + s.value)),
          centreLabel: l10n.biSeatReserved,
        ),
      );
    }
    return out;
  }

  BiCompositionContent _collectionComposition(
    FinanceSummaryKpi inv,
    FinanceSummaryKpi detail,
  ) {
    final parts = collectionComposition(
      invoiced: inv.invoicedMinor,
      collected: detail.collectedMinor,
      collectedLabel: l10n.biCollectionCollected,
      outstandingLabel: l10n.biCollectionOutstanding,
    );
    if (parts == null) {
      return BiCompositionContent(
        title: l10n.biCompositionTitle,
        none: l10n.biCollectionNoComposition,
      );
    }
    final collected = parts.where((p) => p.key == 'collected').firstOrNull;
    return BiCompositionContent(
      title: l10n.biCompositionTitle,
      shares: parts,
      formatValue: format,
      formatShare: share,
      centreValue: share(collected?.share ?? 0),
      centreLabel:
          '${l10n.biCollectionCollected} · ${l10n.biCollectionCentre}',
    );
  }

  BiDashboardContent build() {
    final chipList = chips();
    final forecast = forecastOf(series, aggregation: agg);
    final next = forecast?.points.first;
    final rate = this.rate;
    return BiDashboardContent(
      title: view.title(l10n),
      period: periodLabel(result.period),
      figure: view.value(
        result.total.current.value(agg),
        locale,
        result.currency,
      ),
      basis: view.basis(result.total.current, l10n, locale),
      series: series,
      forecast: forecast,
      chips: chipList,
      bars: bars(),
      compositions: compositions(),
      notes: view.notes(result.total.current, l10n, locale),
      narrative: narrative(),
      provisionalNote: chipList.isNotEmpty && provisional
          ? l10n.biProvisionalNote
          : null,
      runRate: rate == null ? null : l10n.biRunRate(format(rate.projected)),
      projectionBasis: forecast != null
          ? (l10n.biProjectionBasis(forecast.basis))
          : (l10n.biProjectionNotEnough(series.history.length, _need)),
      projectionNext: next == null
          ? null
          : '${periodLabel(next.period)}: ${format(next.value)} '
                '(${format(next.low)} – ${format(next.high)}) · ${l10n.biProjectionLabel}',
      format: format,
      periodLabel: periodLabel,
      shortLabel: (p) => _biShortPeriodLabel(p, locale),
      kindLabel: kindLabel,
      projectedLabel: l10n.biProjectionLabel,
      noDataLabel: l10n.biNoDataLabel,
      partialLabel: l10n.biRunningLabel,
      noComparisonLabel: l10n.biDeltaNone,
      evolutionTitle: l10n.biEvolutionTitle,
      compareTitle: l10n.biCompareTitle,
    );
  }
}
