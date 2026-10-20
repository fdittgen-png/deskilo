// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — the moves the report editor makes on a page's visuals. Ids stay
// with their cards; only the reading order (`layout.order`) is renumbered, so
// it stays unique and 0..n-1.
//
// Pure Dart.
library;

import 'bi_report_visual.dart';

/// [visuals] in reading order.
List<BiReportVisual> biVisualsInOrder(List<BiReportVisual> visuals) =>
    [...visuals]..sort((a, b) => a.layout.order.compareTo(b.layout.order));

/// Moves the visual at [index] (reading order) by [delta]; out of range is no
/// move.
List<BiReportVisual> biMoveVisual(
  List<BiReportVisual> visuals,
  int index,
  int delta,
) {
  final list = biVisualsInOrder(visuals);
  final to = index + delta;
  if (index < 0 || index >= list.length || to < 0 || to >= list.length) {
    return biRenumber(list);
  }
  list.insert(to, list.removeAt(index));
  return biRenumber(list);
}

/// The visuals with `layout.order` set to their position.
List<BiReportVisual> biRenumber(List<BiReportVisual> visuals) => [
  for (final (i, v) in visuals.indexed)
    v.copyWith(layout: v.layout.copyWith(order: i)),
];

/// An id of the form `v<n>` that none of [taken] uses.
String biNextVisualId(Iterable<String> taken) {
  final used = taken.toSet();
  var n = 1;
  while (used.contains('v$n')) {
    n++;
  }
  return 'v$n';
}
