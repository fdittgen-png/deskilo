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
import '../../domain/bi_report_content.dart';
import '../../domain/bi_composition.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_contract.dart';
import 'bi_module_section.dart' show BiModuleView, biChangeLabel;
import 'bi_toolbar.dart' show biPeriodLabel;

export '../../domain/bi_report_content.dart';

/// The short axis label of [p]: "Oct", "Q3", "2026".
String biShortPeriodLabel(BiPeriod p, String locale) => switch (p.grain) {
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
  required AppLocalizations? l10n,
  required String locale,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final agg = module.aggregation;
  String format(num v) => view.value(v, locale, result.currency);
  String periodLabel(BiPeriod p) => biPeriodLabel(p, l10n, locale);
  String changeText(BiChange c) =>
      biChangeLabel(c, l10n, locale, format: format);
  String kindLabel(BiBarKind k) => switch (k) {
    BiBarKind.current => l10n?.biKindCurrent ?? 'Now',
    BiBarKind.previous => l10n?.biKindPrevious ?? 'Previous period',
    BiBarKind.yearAgo => l10n?.biKindYearAgo ?? 'Same period last year',
  };

  final current = series.current;
  final rate = runRateOf(
    current,
    from: from,
    to: to,
    now: now,
    aggregation: agg,
  );
  // What the present is judged by: a finished figure, or — for a running
  // period — its pace (additive) or its figure so far (a ratio), which is
  // marked provisional wherever it is used.
  final num? basis = !current.partial
      ? current.value
      : agg == KpiAggregation.sum
      ? rate?.projected
      : current.value;
  final provisional = current.partial && basis != null;
  BiChange against(BiSeriesPoint? past) =>
      past == null || !past.complete
      ? const BiChange()
      : changeBetween(basis, past.value, agg);

  final chips = <BiChipContent>[
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
              '${kind == BiBarKind.previous ? (l10n?.biVsPrevious ?? 'vs previous period') : (l10n?.biVsYearAgo ?? 'vs last year')}',
        ),
  ];
  final lead = [
    for (final (kind, past) in [
      (BiBarKind.previous, series.previous),
      (BiBarKind.yearAgo, series.yearAgo),
    ])
      if (past != null && past.complete && !against(past).undefined)
        (kind, against(past)),
  ].firstOrNull;
  String? narrative;
  if (lead != null) {
    final label = kindLabel(lead.$1).toLowerCase();
    final words = changeText(lead.$2);
    narrative = switch (directionOf(lead.$2)) {
      BiDirection.up =>
        l10n?.biNarrativeUp(label, words) ?? 'Higher than $label ($words).',
      BiDirection.down =>
        l10n?.biNarrativeDown(label, words) ?? 'Lower than $label ($words).',
      _ => l10n?.biNarrativeFlat(label) ?? 'About the same as $label.',
    };
  }

  final forecast = forecastOf(series, aggregation: agg);
  const need = 4;
  final next = forecast?.points.first;

  final bars = [
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

  final percent = NumberFormat.decimalPercentPattern(
    locale: locale,
    decimalDigits: 1,
  );
  String share(double s) => percent.format(s);
  String hours(num v) =>
      '${NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 1).format(v)} h';
  final compositions = <BiCompositionContent>[];
  final detail = result.total.current.detail;
  final compositionTitle = l10n?.biCompositionTitle ?? 'What it is made of';
  if (detail is SeatCapacityKpi) {
    final labels = SeatTimeLabels(
      reserved: l10n?.biSeatReserved ?? 'Reserved',
      free: l10n?.biSeatFree ?? 'Free during opening hours',
      closed: l10n?.biSeatClosed ?? 'Outside opening hours',
    );
    final parts = seatTimeComposition(detail, labels);
    if (parts != null) {
      final reserved = parts.where((p) => p.key == 'reserved').firstOrNull;
      compositions.add(
        BiCompositionContent(
          title: compositionTitle,
          shares: parts,
          formatValue: hours,
          formatShare: share,
          centreValue: share(reserved?.share ?? 0),
          centreLabel:
              '${labels.reserved} · ${l10n?.biSeatCentre ?? 'of all seat time'}',
        ),
      );
    }
    final rows = extras.groupedByLevel?.groups;
    final byLevel = rows == null
        ? null
        : sharesOf(
            rows,
            labelOf: (r) => r.label ?? r.key,
            otherLabel: l10n?.biRemainder ?? 'Other',
          );
    if (byLevel != null) {
      compositions.add(
        BiCompositionContent(
          title: l10n?.biShareByLevel ?? 'Reserved time by level',
          shares: byLevel,
          formatValue: hours,
          formatShare: share,
          centreValue: hours(byLevel.fold<num>(0, (a, s) => a + s.value)),
          centreLabel: l10n?.biSeatReserved ?? 'Reserved',
        ),
      );
    }
  } else if (module.id == 'finance.collected') {
    final inv = extras.invoiced?.total.current.detail;
    if (inv is FinanceSummaryKpi && detail is FinanceSummaryKpi) {
      final parts = collectionComposition(
        invoiced: inv.invoicedMinor,
        collected: detail.collectedMinor,
        collectedLabel: l10n?.biCollectionCollected ?? 'Collected',
        outstandingLabel: l10n?.biCollectionOutstanding ?? 'Still to collect',
      );
      if (parts == null) {
        compositions.add(
          BiCompositionContent(
            title: compositionTitle,
            none:
                l10n?.biCollectionNoComposition ??
                "The amounts collected here include earlier invoices, so they are not a part of this period's invoiced total.",
          ),
        );
      } else {
        final collected = parts.where((p) => p.key == 'collected').firstOrNull;
        compositions.add(
          BiCompositionContent(
            title: compositionTitle,
            shares: parts,
            formatValue: format,
            formatShare: share,
            centreValue: share(collected?.share ?? 0),
            centreLabel:
                '${l10n?.biCollectionCollected ?? 'Collected'} · ${l10n?.biCollectionCentre ?? 'of what was invoiced'}',
          ),
        );
      }
    }
  }

  return BiDashboardContent(
    title: view.title(l10n),
    period: periodLabel(result.period),
    figure: view.value(result.total.current.value(agg), locale, result.currency),
    basis: view.basis(result.total.current, l10n, locale),
    series: series,
    forecast: forecast,
    chips: chips,
    bars: bars,
    compositions: compositions,
    notes: view.notes(result.total.current, l10n, locale),
    narrative: narrative,
    provisionalNote: chips.isNotEmpty && provisional
        ? l10n?.biProvisionalNote ??
              'Provisional: the period is not over, so this change is an estimate.'
        : null,
    runRate: rate == null
        ? null
        : l10n?.biRunRate(format(rate.projected)) ??
              'At the pace so far, this period would end at about ${format(rate.projected)}.',
    projectionBasis: forecast != null
        ? (l10n?.biProjectionBasis(forecast.basis) ??
              'A straight line through the last ${forecast.basis} complete periods, carried forward. An estimate, not a promise.')
        : (l10n?.biProjectionNotEnough(series.history.length, need) ??
              'Not enough history to project yet: ${series.history.length} complete periods so far, $need needed.'),
    projectionNext: next == null
        ? null
        : '${periodLabel(next.period)}: ${format(next.value)} '
              '(${format(next.low)} – ${format(next.high)}) · ${l10n?.biProjectionLabel ?? 'Estimate'}',
    format: format,
    periodLabel: periodLabel,
    shortLabel: (p) => biShortPeriodLabel(p, locale),
    kindLabel: kindLabel,
    projectedLabel: l10n?.biProjectionLabel ?? 'Estimate',
    noDataLabel: l10n?.biNoDataLabel ?? 'no data',
    partialLabel: l10n?.biRunningLabel ?? 'running',
    noComparisonLabel: l10n?.biDeltaNone ?? 'No comparison yet',
    evolutionTitle: l10n?.biEvolutionTitle ?? 'Evolution',
    compareTitle: l10n?.biCompareTitle ?? 'Compared with the past',
  );
}
