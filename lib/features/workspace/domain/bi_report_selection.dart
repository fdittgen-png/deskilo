// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A temporary selection on a report page: the person picks one group (a
// bar, a table row) of a visual whose interaction is `filter`, and the other
// visuals of the SAME page that answer that grouping show that group only.
//   * one level: the selection comes from one visual and is applied to the
//     others once — a filtered visual never filters a third, so there is no
//     cycle and no cascade of reads;
//   * a visual whose figure does not answer the grouping is left as it is
//     and says why; a text is never filtered;
//   * the selection only narrows: it is intersected with the report's, the
//     page's and the visual's own filters (`scopeOf`), and a selection those
//     do not admit is refused, never read as an override;
//   * it is local to the page on screen and never written into the report.
//
// Pure Dart.
library;

import 'bi_report_definition.dart';
import 'bi_report_rules.dart';
import 'bi_result.dart';
import 'kpi_contract.dart';

class BiReportSelection {
  const BiReportSelection({
    required this.pageId,
    required this.visualId,
    required this.dimension,
    required this.key,
    this.label,
  });

  final String pageId;

  /// The visual the group was picked on.
  final String visualId;
  final String dimension;

  /// The group's id (a level id, never its name).
  final String key;

  /// The group's display name, as the source visual showed it.
  final String? label;

  /// The selection as a report filter.
  BiReportFilter get filter => BiReportFilter(dimension, 'eq', key);
}

/// What a selection does to one visual of the page.
enum BiCrossFilter {
  /// The visual the selection was made on.
  source,

  /// The visual shows the selected group only.
  filtered,

  /// The visual's figure does not answer the selection's grouping.
  unsupported,

  /// The report's, page's or visual's filters do not admit the selection.
  outsideScope,

  /// A text, which no selection changes.
  unaffected,
}

/// The selection picking [row] on [source] of [page]; null when [source]
/// does not filter (interaction `none`, no grouping) or [row] is not a group.
BiReportSelection? biSelectionOf(
  BiReportPage page,
  BiReportVisual source,
  BiRow row,
) {
  final dimension = source.dimension;
  if (source.interaction != 'filter' || dimension == null) return null;
  if (row.isTotal || row.isRemainder) return null;
  return BiReportSelection(
    pageId: page.id,
    visualId: source.id,
    dimension: dimension,
    key: row.key,
    label: row.label,
  );
}

/// What [selection] does to [target] of [page] in [report].
BiCrossFilter biCrossFilterOf(
  BiReportDefinition report,
  BiReportPage page,
  BiReportVisual target,
  BiReportSelection selection,
) {
  if (target.id == selection.visualId) return BiCrossFilter.source;
  if (target.type == BiVisualType.text) return BiCrossFilter.unaffected;
  final module = biModuleOf(target.metricId);
  // A line is a figure over time; its series is not split by group.
  if (module == null ||
      target.type == BiVisualType.line ||
      !biDimensionsOf(module).contains(selection.dimension)) {
    return BiCrossFilter.unsupported;
  }
  return report.scopeOf(page, target, selection: [selection.filter]) == null
      ? BiCrossFilter.outsideScope
      : BiCrossFilter.filtered;
}

/// How a visual reads its figure under the filters that reach it: grouped
/// by [groupBy] (its own grouping, else the dimension of the filters it can
/// apply), with the filters [applied] to those groups; the [unapplied] ones
/// name a grouping the figure does not answer, and the visual says so
/// instead of pretending to be filtered.
class BiReadPlan {
  const BiReadPlan({
    required this.groupBy,
    required this.applied,
    required this.unapplied,
  });

  final String? groupBy;
  final List<BiReportFilter> applied;
  final List<BiReportFilter> unapplied;
}

/// The plan of [visual] under [scope] (report ∩ page ∩ visual ∩ selection).
BiReadPlan biReadPlanOf(BiReportVisual visual, List<BiReportFilter> scope) {
  final module = biModuleOf(visual.metricId);
  final answered = module == null || visual.type == BiVisualType.line
      ? const <String>{}
      : biDimensionsOf(module);
  final dimension =
      visual.dimension ??
      scope.map((f) => f.dimension).where(answered.contains).firstOrNull;
  return BiReadPlan(
    groupBy: visual.type == BiVisualType.line ? null : dimension,
    applied: [
      for (final f in scope)
        if (f.dimension == dimension && answered.contains(f.dimension)) f,
    ],
    unapplied: [
      for (final f in scope)
        if (f.dimension != dimension || !answered.contains(f.dimension)) f,
    ],
  );
}

/// The groups of [result] every filter in [filters] admits. A remainder
/// (time no current group explains) is no named group: a positive filter
/// leaves it out, an exclusion keeps it.
List<BiRow> biRowsIn(BiResult result, List<BiReportFilter> filters) => [
  for (final r in result.groups)
    if (filters.every(
      (f) => f.positive
          ? !r.isRemainder && f.values.contains(r.key)
          : r.isRemainder || r.key != f.value,
    ))
      r,
];

/// [rows] as one total: numerators and denominators summed (a ratio of
/// sums, never a mean of ratios), every quality kept — an unknown part
/// leaves the whole unknown, never a smaller number.
BiRow biTotalOf(List<BiRow> rows) {
  num numerator = 0;
  num? denominator;
  final quality = <KpiQuality>{};
  final reasons = <String>[];
  for (final r in rows) {
    numerator += r.current.numerator;
    if (r.current.denominator case final d?) {
      denominator = (denominator ?? 0) + d;
    }
    quality.addAll(r.current.quality);
    reasons.addAll(r.current.reasons);
  }
  if (rows.isEmpty) quality.add(KpiQuality.notApplicable);
  return BiRow(
    key: BiRow.totalKey,
    label: null,
    current: BiMeasure(
      numerator: numerator,
      denominator: denominator,
      quality: quality,
      reasons: reasons,
    ),
  );
}
