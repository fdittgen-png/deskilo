// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the canonical result every Web-BI module returns, and the
// comparison arithmetic. The chart and the table render THESE rows; no
// widget computes a figure of its own.
//
// A measure keeps its numerator and denominator, so a total over groups
// is sum(numerators) / sum(denominators) and never the mean of child
// ratios. A value is null — undefined, not zero — when the denominator
// is zero, when the period was not recorded, or when the source could
// not answer. A change against a null or zero base is undefined too.
//
// Pure Dart.
library;

import 'bi_modules.dart';
import 'bi_query.dart';
import 'kpi_contract.dart';

/// One figure: what the server returned for one group and one period.
class BiMeasure {
  const BiMeasure({
    required this.numerator,
    this.denominator,
    this.quality = const {},
    this.reasons = const [],
    this.historySince,
    this.detail,
  });

  final num numerator;

  /// The base of a ratio; null for an additive measure.
  final num? denominator;
  final Set<KpiQuality> quality;

  /// The server's machine reasons behind [quality].
  final List<String> reasons;

  /// When the recorded history begins (#1920), if the source says.
  final DateTime? historySince;

  /// The module's typed payload, for its own explanation lines.
  final Object? detail;

  /// Nothing to show: before the history, or no answer.
  bool get unknown =>
      quality.contains(KpiQuality.notRecorded) ||
      quality.contains(KpiQuality.unavailable) ||
      quality.contains(KpiQuality.forbidden);

  /// The figure under [aggregation], or null when it is undefined.
  num? value(KpiAggregation aggregation) {
    if (unknown) return null;
    return switch (aggregation) {
      KpiAggregation.sum => numerator,
      KpiAggregation.ratioOfSums => ratioOfSums([
        (numerator: numerator, denominator: denominator ?? 0),
      ]),
    };
  }
}

/// One row: a group (or the total) in the current and compared period.
class BiRow {
  const BiRow({
    required this.key,
    required this.label,
    required this.current,
    this.compared,
  });

  /// The group's id, `total`, or `remainder`.
  final String key;

  /// The group's display name; null for the total and the remainder,
  /// which the view names.
  final String? label;
  final BiMeasure current;
  final BiMeasure? compared;

  bool get isTotal => key == totalKey;
  bool get isRemainder => key == remainderKey;

  static const totalKey = 'total';
  static const remainderKey = 'remainder';
}

/// A module's answer to one [BiQueryContext].
class BiResult {
  const BiResult({
    required this.period,
    required this.total,
    this.comparedPeriod,
    this.groups = const [],
    required this.computedAt,
  });

  final BiPeriod period;
  final BiPeriod? comparedPeriod;
  final BiRow total;

  /// The grouped rows, already sorted; empty when not grouped. A
  /// remainder row (time no current group explains) comes last.
  final List<BiRow> groups;
  final DateTime computedAt;
}

/// The change from a compared value to the current one.
class BiChange {
  const BiChange({this.absolute, this.relative, this.points});

  /// current − compared, in the measure's unit (additive measures).
  final num? absolute;

  /// (current − compared) / |compared|; null on a zero or null base.
  final double? relative;

  /// For ratios: the difference in percentage points.
  final double? points;

  bool get undefined => absolute == null && relative == null && points == null;
}

/// The change of [row] under [aggregation]. Every part is null when
/// either side is undefined: a missing base is never read as zero.
BiChange changeOf(BiRow row, KpiAggregation aggregation) {
  final compared = row.compared;
  if (compared == null) return const BiChange();
  final now = row.current.value(aggregation);
  final then = compared.value(aggregation);
  if (now == null || then == null) return const BiChange();
  return switch (aggregation) {
    KpiAggregation.ratioOfSums => BiChange(points: (now - then) * 100),
    KpiAggregation.sum => BiChange(
      absolute: now - then,
      relative: then == 0 ? null : (now - then) / then.abs(),
    ),
  };
}

/// The bases of a ratio differ between the two periods (another
/// capacity, other opening hours): the ratio accounts for it, the raw
/// numerators do not compare directly.
bool exposureDiffers(BiRow row) {
  final a = row.current.denominator, b = row.compared?.denominator;
  if (a == null || b == null || row.compared!.unknown) return false;
  return a != b;
}

/// What the total holds that no group explains (a group that no longer
/// exists, time outside every group), or null when nothing is left.
BiMeasure? remainderOf(BiMeasure total, Iterable<BiMeasure> groups) {
  if (total.unknown) return null;
  num n = total.numerator, d = total.denominator ?? 0;
  for (final g in groups) {
    if (g.unknown) return null;
    n -= g.numerator;
    d -= g.denominator ?? 0;
  }
  // The server rounds each figure to 0.01; a difference below that is
  // rounding, not a group.
  if (n.abs() < 0.015 && d.abs() < 0.015) return null;
  return BiMeasure(
    numerator: n,
    denominator: total.denominator == null ? null : d,
    quality: {KpiQuality.partial},
    reasons: const ['outside_current_groups'],
  );
}

/// [rows] in [sort] order; undefined values sort last.
List<BiRow> sortRows(
  List<BiRow> rows,
  BiSort sort,
  KpiAggregation aggregation,
) {
  if (sort == BiSort.natural) return rows;
  final sorted = [...rows]
    ..sort((a, b) {
      final x = a.current.value(aggregation), y = b.current.value(aggregation);
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return sort == BiSort.valueDescending ? y.compareTo(x) : x.compareTo(y);
    });
  return sorted;
}

/// The module cannot answer this context (an unsupported grain,
/// comparison or grouping, or more groups than the budget). Explained,
/// never answered with an unfiltered figure.
class BiRefused implements Exception {
  const BiRefused(this.reasons, {this.groupBudgetExceeded = false});

  final Set<BiUnsupported> reasons;
  final bool groupBudgetExceeded;
}
