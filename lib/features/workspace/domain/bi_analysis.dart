// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Business analytics presentation core: what the dashboard and the PDF
// both say about a figure — its past, how now compares with then, where it
// is going and what it is made of. Every number the screen and the report
// show comes from here, so they cannot disagree.
//
// It adds no figure of its own to the data: the series are the module's own
// answers for earlier periods; a period the data does not know is a gap,
// never a zero; a projection is an ESTIMATE, labelled as one, and is only
// made from complete periods and only when there are enough of them. The
// run-rate of the running period is offered only for additive measures
// (hours or money accumulate; a ratio does not).
//
// Pure Dart.
library;

import 'dart:math' as math;

import 'bi_query.dart';
import 'bi_result.dart';
import 'kpi_contract.dart';

/// One period of a series.
class BiSeriesPoint {
  const BiSeriesPoint({required this.period, this.value, this.partial = false});

  final BiPeriod period;

  /// The figure, or null when the data does not know it.
  final num? value;

  /// The period is not over, or only partly recorded: its figure will
  /// still change, or does not cover the whole period.
  final bool partial;

  bool get known => value != null;

  /// A figure that can be compared and extrapolated from.
  bool get complete => known && !partial;
}

/// The figure over consecutive periods, oldest first; the last is the
/// period being looked at.
class BiSeries {
  const BiSeries(this.points);

  final List<BiSeriesPoint> points;

  bool get isEmpty => points.isEmpty;
  BiSeriesPoint get current => points.last;

  /// The point [by] periods before the current one, if the series has it.
  BiSeriesPoint? before(int by) {
    final wanted = current.period.shift(-by);
    for (final p in points) {
      if (p.period == wanted) return p;
    }
    return null;
  }

  BiSeriesPoint? get previous => before(1);

  /// The same period one year earlier.
  BiSeriesPoint? get yearAgo => before(current.period.grain.perYear);

  /// The complete periods before the current one.
  List<BiSeriesPoint> get history => [
    for (final p in points.take(points.length - 1))
      if (p.complete) p,
  ];
}

/// Which way a figure moved.
enum BiDirection { up, down, flat, unknown }

/// How [now] changed from [then] — the same arithmetic as [changeOf], for
/// two plain values. A missing or partial side is undefined, never zero.
BiChange changeBetween(num? now, num? then, KpiAggregation aggregation) {
  if (now == null || then == null) return const BiChange();
  return switch (aggregation) {
    KpiAggregation.ratioOfSums => BiChange(points: (now - then) * 100),
    KpiAggregation.sum => BiChange(
      absolute: now - then,
      relative: then == 0 ? null : (now - then) / then.abs(),
    ),
  };
}

/// The direction of [change]: within [tolerance] (a fraction, or points for
/// a ratio) it is flat.
BiDirection directionOf(BiChange change, {double tolerance = 0.005}) {
  final points = change.points;
  if (points != null) {
    if (points.abs() < tolerance * 100) return BiDirection.flat;
    return points > 0 ? BiDirection.up : BiDirection.down;
  }
  final relative = change.relative;
  if (relative != null) {
    if (relative.abs() < tolerance) return BiDirection.flat;
    return relative > 0 ? BiDirection.up : BiDirection.down;
  }
  final absolute = change.absolute;
  if (absolute != null) {
    if (absolute == 0) return BiDirection.flat;
    return absolute > 0 ? BiDirection.up : BiDirection.down;
  }
  return BiDirection.unknown;
}

/// One bar of the past-versus-present comparison.
class BiComparisonBar {
  const BiComparisonBar({
    required this.kind,
    required this.period,
    required this.value,
    required this.partial,
  });

  /// `current`, `previous` or `yearAgo`.
  final BiBarKind kind;
  final BiPeriod period;
  final num? value;
  final bool partial;
}

enum BiBarKind { current, previous, yearAgo }

/// The bars that say how now compares with the past: the current period,
/// the one before it, and the same one a year earlier — each only when the
/// series has it.
List<BiComparisonBar> comparisonBars(BiSeries series) {
  if (series.isEmpty) return const [];
  BiComparisonBar bar(BiBarKind kind, BiSeriesPoint p) => BiComparisonBar(
    kind: kind,
    period: p.period,
    value: p.value,
    partial: p.partial,
  );
  return [
    ?series.previous == null ? null : bar(BiBarKind.previous, series.previous!),
    ?series.yearAgo == null ? null : bar(BiBarKind.yearAgo, series.yearAgo!),
    bar(BiBarKind.current, series.current),
  ];
}

/// Where an additive figure of the RUNNING period is heading at its
/// present pace: what has accumulated, scaled to the whole period.
class BiRunRate {
  const BiRunRate({
    required this.projected,
    required this.elapsed,
  });

  /// The estimated total at the end of the period.
  final num projected;

  /// How much of the period has passed (0–1).
  final double elapsed;
}

/// The run-rate of [point] for the period `[from, to)` at [now], or null
/// when it does not apply: the measure is a ratio, the period is over or
/// has not started, too little of it has passed (under [minElapsed]) to say
/// anything, or the figure is unknown.
BiRunRate? runRateOf(
  BiSeriesPoint point, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
  required KpiAggregation aggregation,
  double minElapsed = 0.15,
}) {
  final value = point.value;
  if (aggregation != KpiAggregation.sum || value == null) return null;
  if (!point.partial || !now.isAfter(from) || !to.isAfter(now)) return null;
  final total = to.difference(from).inMinutes;
  if (total <= 0) return null;
  final elapsed = now.difference(from).inMinutes / total;
  if (elapsed < minElapsed) return null;
  return BiRunRate(projected: value / elapsed, elapsed: elapsed);
}

/// One projected period, with the range it is likely to fall in.
class BiForecastPoint {
  const BiForecastPoint({
    required this.period,
    required this.value,
    required this.low,
    required this.high,
  });

  final BiPeriod period;
  final double value;
  final double low;
  final double high;
}

/// A straight-line projection of the complete periods that came before.
class BiForecast {
  const BiForecast({
    required this.points,
    required this.slope,
    required this.basis,
  });

  final List<BiForecastPoint> points;

  /// The change per period of the fitted line.
  final double slope;

  /// How many complete periods the line was fitted on.
  final int basis;
}

/// The least-squares line through the complete periods of [series] before
/// the current one, carried [horizon] periods past the current one. Null
/// when there are fewer than [minPoints] complete periods: a projection
/// from almost nothing is not offered. The range is the line's own scatter
/// (one standard error, widening away from the data); it says "likely",
/// not "certain". A figure that cannot be negative is not projected below
/// zero, and a ratio not above 1.
BiForecast? forecastOf(
  BiSeries series, {
  required KpiAggregation aggregation,
  int horizon = 3,
  int minPoints = 4,
}) {
  final history = series.history;
  if (history.length < minPoints || series.isEmpty) return null;
  final origin = history.first.period;
  double x(BiPeriod p) => origin.distanceTo(p).toDouble();
  final xs = [for (final p in history) x(p.period)];
  final ys = [for (final p in history) p.value!.toDouble()];
  final n = xs.length;
  final xMean = xs.reduce((a, b) => a + b) / n;
  final yMean = ys.reduce((a, b) => a + b) / n;
  var sxx = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sxx += (xs[i] - xMean) * (xs[i] - xMean);
    sxy += (xs[i] - xMean) * (ys[i] - yMean);
  }
  if (sxx == 0) return null;
  final slope = sxy / sxx;
  final intercept = yMean - slope * xMean;
  var rss = 0.0;
  for (var i = 0; i < n; i++) {
    final r = ys[i] - (intercept + slope * xs[i]);
    rss += r * r;
  }
  final sigma = n > 2 ? math.sqrt(rss / (n - 2)) : 0.0;
  final cap = aggregation == KpiAggregation.ratioOfSums ? 1.0 : double.infinity;
  double clamp(double v) => v.clamp(0.0, cap).toDouble();
  final points = <BiForecastPoint>[];
  for (var h = 1; h <= horizon; h++) {
    final period = series.current.period.shift(h);
    final px = x(period);
    final centre = intercept + slope * px;
    final widen = math.sqrt(1 + 1 / n + math.pow(px - xMean, 2) / sxx);
    points.add(
      BiForecastPoint(
        period: period,
        value: clamp(centre),
        low: clamp(centre - sigma * widen),
        high: clamp(centre + sigma * widen),
      ),
    );
  }
  return BiForecast(points: points, slope: slope, basis: n);
}

/// One part of a whole.
class BiShare {
  const BiShare({
    required this.key,
    required this.label,
    required this.value,
    required this.share,
    this.isOther = false,
  });

  final String key;
  final String label;

  /// The part's own amount (of the measure's numerator).
  final num value;

  /// Its fraction of the whole (0–1).
  final double share;

  /// The parts folded together because there are more than the chart can
  /// tell apart.
  final bool isOther;
}

/// What the groups of a result are made of: each group's part of the
/// whole, largest first, the smallest folded into one "other" part beyond
/// [maxItems]. The whole is the sum of the groups, never the total row's
/// figure. Null when it would not be meaningful: no groups, any part
/// unknown or negative, or nothing in them.
List<BiShare>? sharesOf(
  List<BiRow> groups, {
  required String Function(BiRow row) labelOf,
  required String otherLabel,
  int maxItems = 6,
}) {
  final parts = <(BiRow, num)>[];
  for (final g in groups) {
    if (g.isRemainder) continue;
    if (g.current.unknown || !g.current.numerator.isFinite) return null;
    if (g.current.numerator < 0) return null;
    parts.add((g, g.current.numerator));
  }
  if (parts.length < 2) return null;
  final whole = parts.fold<num>(0, (a, p) => a + p.$2);
  if (whole <= 0) return null;
  parts.sort((a, b) => b.$2.compareTo(a.$2));
  final shown = parts.take(maxItems).toList();
  final folded = parts.skip(maxItems).toList();
  return [
    for (final (row, value) in shown)
      BiShare(
        key: row.key,
        label: labelOf(row),
        value: value,
        share: value / whole,
      ),
    if (folded.isNotEmpty)
      BiShare(
        key: 'other',
        label: otherLabel,
        value: folded.fold<num>(0, (a, p) => a + p.$2),
        share: folded.fold<num>(0, (a, p) => a + p.$2) / whole,
        isOther: true,
      ),
  ];
}
