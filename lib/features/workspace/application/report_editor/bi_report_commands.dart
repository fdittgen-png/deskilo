// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The report editor's commands: each takes the report and the page on
// screen and returns the next report, or the reason it was refused (the
// report is then unchanged). They are pure, so the editor's history is just
// the list of reports they produced, and Undo/Redo step through it.
//   * ids are minted once and travel with their visual: a move or a resize
//     never renames anything, a duplicate gets a new id;
//   * the reading order is renumbered 0..n-1 after every change;
//   * the space's limits (`bi.report_max_*`) stop an addition, never a save
//     the person already made;
//   * a filter only narrows the level above it (#2579's intersection);
//   * a choice the figure cannot keep is refused by the binding rules.
//
// Pure Dart.
library;

import '../../domain/bi_report_definition.dart';
import '../../domain/bi_report_edit.dart';
import '../../domain/bi_report_limits.dart';
import '../../domain/bi_report_rules.dart';

/// Why a command did nothing.
enum BiEditRefusal {
  /// The space's limit of visuals or pages is reached.
  limit,

  /// A report keeps at least one page.
  lastPage,

  /// A filter would widen the level above it.
  widens,

  /// The visual named is not on the page.
  missing,

  /// A page title or a text is empty or too long.
  invalidText,
}

/// A command's outcome.
class BiEdit {
  const BiEdit(this.report, {this.page, this.selected})
    : refusal = null,
      binding = null;
  const BiEdit.refused(BiEditRefusal this.refusal)
    : report = null,
      page = null,
      selected = null,
      binding = null;
  const BiEdit.unbound(BiBindingRefusal this.binding)
    : report = null,
      page = null,
      selected = null,
      refusal = null;

  final BiReportDefinition? report;

  /// The page to show afterwards, when the command moves it.
  final int? page;

  /// The visual to select (and focus) afterwards.
  final String? selected;
  final BiEditRefusal? refusal;
  final BiBindingRefusal? binding;
}

/// Every id in [report], pages and visuals together.
Iterable<String> _ids(BiReportDefinition report) => [
  for (final p in report.pages) ...[p.id, ...p.visuals.map((v) => v.id)],
];

BiReportPage _page(
  BiReportPage p, {
  String? title,
  List<BiReportVisual>? visuals,
  List<BiReportFilter>? filters,
}) => BiReportPage(
  id: p.id,
  title: title ?? p.title,
  filters: filters ?? p.filters,
  visuals: visuals ?? p.visuals,
);

BiReportDefinition _withPages(
  BiReportDefinition r,
  List<BiReportPage> pages, {
  List<BiReportFilter>? filters,
}) => BiReportDefinition(
  period: r.period,
  pages: pages,
  filters: filters ?? r.filters,
  printStyle: r.printStyle,
);

/// Adds a visual of [type] for [metricId] (or the plain [text]) at the end of
/// page [page].
BiEdit biAddVisual(
  BiReportDefinition report,
  int page,
  BiVisualType type, {
  String? metricId,
  String? text,
  BiReportLimits limits = const BiReportLimits(),
}) {
  if (!limits.canAddVisual(report)) {
    return const BiEdit.refused(BiEditRefusal.limit);
  }
  final p = report.pages[page];
  final id = biNextVisualId(_ids(report));
  final layout = BiVisualLayout.defaultFor(type, p.visuals.length);
  final BiReportVisual visual;
  if (type == BiVisualType.text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty || t.length > BiReportVisual.maxText) {
      return const BiEdit.refused(BiEditRefusal.invalidText);
    }
    visual = BiReportVisual(
      id: id,
      type: type,
      layout: layout,
      interaction: 'none',
      text: t,
    );
  } else {
    final kpi = BiReportVisual.kpi(
      id: id,
      metricId: metricId ?? '',
      layout: layout,
    );
    final bound = type == BiVisualType.kpi
        ? biChecked(kpi)
        : biSetType(kpi, type);
    if (bound.refusal case final r?) return BiEdit.unbound(r);
    visual = bound.visual!.copyWith(layout: layout);
  }
  return BiEdit(
    report.withPage(
      page,
      p.withVisuals(biRenumber([...biVisualsInOrder(p.visuals), visual])),
    ),
    selected: id,
  );
}

/// The visual [id] of page [page], or null.
BiReportVisual? _visualOn(BiReportDefinition report, int page, String id) =>
    report.pages[page].visuals.where((v) => v.id == id).firstOrNull;

BiEdit _replace(
  BiReportDefinition report,
  int page,
  String id,
  BiReportVisual Function(BiReportVisual v) change,
) {
  final p = report.pages[page];
  if (_visualOn(report, page, id) == null) {
    return const BiEdit.refused(BiEditRefusal.missing);
  }
  return BiEdit(
    report.withPage(
      page,
      p.withVisuals([
        for (final v in p.visuals)
          if (v.id == id) change(v) else v,
      ]),
    ),
    selected: id,
  );
}

/// Applies the binding change [change] to visual [id]; a refusal leaves the
/// report as it was and says why.
BiEdit biChangeVisual(
  BiReportDefinition report,
  int page,
  String id,
  BiBinding Function(BiReportVisual v) change,
) {
  final v = _visualOn(report, page, id);
  if (v == null) return const BiEdit.refused(BiEditRefusal.missing);
  final bound = change(v);
  if (bound.refusal case final r?) return BiEdit.unbound(r);
  return _replace(report, page, id, (_) => bound.visual!);
}

/// Replaces the plain text of the text visual [id].
BiEdit biSetText(BiReportDefinition report, int page, String id, String text) {
  final t = text.trim();
  if (t.isEmpty || t.length > BiReportVisual.maxText) {
    return const BiEdit.refused(BiEditRefusal.invalidText);
  }
  final v = _visualOn(report, page, id);
  if (v == null || v.type != BiVisualType.text) {
    return const BiEdit.refused(BiEditRefusal.missing);
  }
  return _replace(report, page, id, (v) => v.copyWith(text: t));
}

/// Moves visual [id] by [delta] places in the reading order.
BiEdit biMoveVisualBy(
  BiReportDefinition report,
  int page,
  String id,
  int delta,
) {
  final p = report.pages[page];
  final ordered = biVisualsInOrder(p.visuals);
  final index = ordered.indexWhere((v) => v.id == id);
  if (index < 0) return const BiEdit.refused(BiEditRefusal.missing);
  return BiEdit(
    report.withPage(page, p.withVisuals(biMoveVisual(ordered, index, delta))),
    selected: id,
  );
}

/// Widens (or narrows, [span] negative) and heightens visual [id] by grid
/// steps, within the grid's bounds.
BiEdit biResizeVisual(
  BiReportDefinition report,
  int page,
  String id, {
  int span = 0,
  int height = 0,
}) => _replace(
  report,
  page,
  id,
  (v) => v.copyWith(
    layout: v.layout.copyWith(
      span: (v.layout.span + span).clamp(1, BiVisualLayout.maxSpan),
      height: (v.layout.height + height).clamp(1, BiVisualLayout.maxHeight),
    ),
  ),
);

/// A copy of visual [id] right after it, with a new id; the original is
/// unchanged.
BiEdit biDuplicateVisual(
  BiReportDefinition report,
  int page, {
  required String id,
  BiReportLimits limits = const BiReportLimits(),
}) {
  if (!limits.canAddVisual(report)) {
    return const BiEdit.refused(BiEditRefusal.limit);
  }
  final p = report.pages[page];
  final ordered = biVisualsInOrder(p.visuals);
  final index = ordered.indexWhere((v) => v.id == id);
  if (index < 0) return const BiEdit.refused(BiEditRefusal.missing);
  final copy = ordered[index].copyWith(id: biNextVisualId(_ids(report)));
  ordered.insert(index + 1, copy);
  return BiEdit(
    report.withPage(page, p.withVisuals(biRenumber(ordered))),
    selected: copy.id,
  );
}

/// Removes visual [id]; the next one (else the previous) is selected.
BiEdit biDeleteVisual(BiReportDefinition report, int page, String id) {
  final p = report.pages[page];
  final ordered = biVisualsInOrder(p.visuals);
  final index = ordered.indexWhere((v) => v.id == id);
  if (index < 0) return const BiEdit.refused(BiEditRefusal.missing);
  ordered.removeAt(index);
  final next = ordered.isEmpty
      ? null
      : ordered[index.clamp(0, ordered.length - 1)].id;
  return BiEdit(
    report.withPage(page, p.withVisuals(biRenumber(ordered))),
    selected: next,
  );
}

/// A new empty page titled [title] after the last one, then shown.
BiEdit biAddPage(
  BiReportDefinition report,
  String title, {
  BiReportLimits limits = const BiReportLimits(),
}) {
  if (!limits.canAddPage(report)) {
    return const BiEdit.refused(BiEditRefusal.limit);
  }
  if (!_validTitle(title)) {
    return const BiEdit.refused(BiEditRefusal.invalidText);
  }
  final page = BiReportPage(
    id: biNextPageId(_ids(report)),
    title: title.trim(),
  );
  return BiEdit(
    report.withPage(report.pages.length, page),
    page: report.pages.length,
  );
}

bool _validTitle(String title) {
  final t = title.trim();
  return t.isNotEmpty && t.length <= BiReportPage.maxTitle;
}

/// Page [page] titled [title].
BiEdit biRenamePage(BiReportDefinition report, int page, String title) {
  if (!_validTitle(title)) {
    return const BiEdit.refused(BiEditRefusal.invalidText);
  }
  return BiEdit(
    report.withPage(page, _page(report.pages[page], title: title.trim())),
  );
}

/// Moves page [page] by [delta] places; it stays the page shown.
BiEdit biMovePage(BiReportDefinition report, int page, int delta) {
  final to = page + delta;
  if (to < 0 || to >= report.pages.length) return BiEdit(report, page: page);
  final pages = [...report.pages];
  pages.insert(to, pages.removeAt(page));
  return BiEdit(_withPages(report, pages), page: to);
}

/// Removes page [page] and its visuals; a report keeps at least one page.
BiEdit biDeletePage(BiReportDefinition report, int page) {
  if (report.pages.length <= 1) {
    return const BiEdit.refused(BiEditRefusal.lastPage);
  }
  final pages = [...report.pages]..removeAt(page);
  return BiEdit(
    _withPages(report, pages),
    page: page.clamp(0, pages.length - 1),
  );
}

/// The report's filters ([page] null) or page [page]'s, set to [filters].
/// A level that would widen the one above it, or leave a lower level wider
/// than itself, is refused.
BiEdit _setFilters(
  BiReportDefinition report,
  int? page,
  List<BiReportFilter> filters,
) {
  final pages = [
    for (final (i, p) in report.pages.indexed)
      if (i == page) _page(p, filters: filters) else p,
  ];
  final reportFilters = page == null ? filters : report.filters;
  for (final p in pages) {
    if (!biFiltersNarrow(reportFilters, p.filters)) {
      return const BiEdit.refused(BiEditRefusal.widens);
    }
    for (final v in p.visuals) {
      if (!biFiltersNarrow([...reportFilters, ...p.filters], v.filters)) {
        return const BiEdit.refused(BiEditRefusal.widens);
      }
    }
  }
  return BiEdit(_withPages(report, pages, filters: reportFilters), page: page);
}

/// Page [page]'s filters with [filter] added; a filter of the same dimension
/// is replaced (one per dimension and level). Refused when the page is full
/// or the filter would widen the report's.
BiEdit biAddPageFilter(
  BiReportDefinition report,
  int page,
  BiReportFilter filter,
) {
  final kept = [
    for (final f in report.pages[page].filters)
      if (f.dimension != filter.dimension) f,
  ];
  if (kept.length >= BiReportFilter.maxPerLevel) {
    return const BiEdit.refused(BiEditRefusal.limit);
  }
  return _setFilters(report, page, [...kept, filter]);
}

/// The report's filters ([page] null) or page [page]'s without filter
/// [index]. Removing a filter of the report may leave a lower level naming
/// a value the report no longer limits: that only narrows, so it stays.
BiEdit biRemoveFilter(BiReportDefinition report, int? page, int index) {
  final filters = page == null ? report.filters : report.pages[page].filters;
  if (index < 0 || index >= filters.length) {
    return const BiEdit.refused(BiEditRefusal.missing);
  }
  return _setFilters(report, page, [...filters]..removeAt(index));
}
