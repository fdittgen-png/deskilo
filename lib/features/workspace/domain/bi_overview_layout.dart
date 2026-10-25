// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2583 C2 / #2580 — a person's own layout of the workspace overview's key
// indicators: which figures are pinned, in which order. It is a saved report
// like any other (#2579's store: one revision per save, a stale save refused,
// a retried request applied once), private to its author, whose one page has
// the id [_overviewPageId]: so two people's layouts never touch, a layout
// survives a restart and another device, and it opens in the report editor
// and the analytics page as what it is.
//
// The layout names questions, never answers: a pinned figure the reader may
// not read (any more) is not shown, and an unknown value still reads "Not
// available" on its tile.
//
// Pure Dart.
library;

import 'bi_query.dart';
import 'bi_report_definition.dart';
import 'bi_saved_view.dart';

/// The page id that marks a saved report as its author's overview layout.
const _overviewPageId = 'overview';

/// The reader's own overview layout among [views], or null (the standard,
/// registry-ordered overview).
BiSavedView? biOverviewLayoutOf(List<BiSavedView> views) => views
    .where(
      (v) =>
          v.scope == BiViewScope.private &&
          v.mine &&
          v.definition?.report?.pages.firstOrNull?.id == _overviewPageId,
    )
    .firstOrNull;

/// The figures [report]'s first page names, in reading order, each once.
List<String> biTilesOf(BiReportDefinition report) =>
    BiReportDefinition.cardsOf(report.pages.first).toSet().toList();

/// [tiles] as the one page of an overview layout: a figure card each, a
/// quarter of the wide grid, of the current month.
BiReportDefinition biOverviewReport(
  List<String> tiles, {
  required String title,
}) => BiReportDefinition(
  period: const BiReportPeriod.relative(BiGrain.month, 0),
  pages: [
    BiReportPage(
      id: _overviewPageId,
      title: title,
      visuals: [
        for (final (i, t) in tiles.indexed)
          BiReportVisual.kpi(
            id: 'v${i + 1}',
            metricId: t,
            layout: BiVisualLayout(order: i, span: 3, height: 1),
          ),
      ],
    ),
  ],
);

/// [tiles] with [id] pinned at the end (already pinned: unchanged).
List<String> biPinTile(List<String> tiles, String id) =>
    tiles.contains(id) ? tiles : [...tiles, id];

/// [tiles] without [id].
List<String> biUnpinTile(List<String> tiles, String id) => [
  for (final t in tiles)
    if (t != id) t,
];

/// [tiles] with [id] moved by [delta] places; out of range is no move.
List<String> biMoveTile(List<String> tiles, String id, int delta) {
  final from = tiles.indexOf(id);
  final to = from + delta;
  if (from < 0 || to < 0 || to >= tiles.length) return tiles;
  final next = [...tiles]..removeAt(from);
  return next..insert(to, id);
}
