// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — an analytical report: version 2 of a saved Web-BI view. A bounded
// declarative document of pages, each a grid of visuals bound to a registered
// metric. Like a v1 view it holds questions, never answers or privileges: no
// figures, no SQL, no formulas, no links, no HTML. Text is plain content
// that the reader shows escaped.
//
// A v1 definition is read as one virtual page ([BiReportDefinition.standard])
// and never written back as v2 unless the person promotes a copy.
//
// Pure Dart. The same shape is checked by `bi_definition_valid` on the server.
library;

import 'dart:convert';

import 'bi_query.dart';
import 'bi_report_visual.dart';

export 'bi_report_visual.dart';

class BiReportPage {
  const BiReportPage({
    required this.id,
    required this.title,
    this.filters = const [],
    this.visuals = const [],
  });

  final String id;
  final String title;
  final List<BiReportFilter> filters;
  final List<BiReportVisual> visuals;

  BiReportPage withVisuals(List<BiReportVisual> next) =>
      BiReportPage(id: id, title: title, filters: filters, visuals: next);

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'filters': [for (final f in filters) f.toJson()],
    'visuals': [for (final v in visuals) v.toJson()],
  };

  static BiReportPage? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null ||
        !biReportOnly(r, const {'id', 'title', 'filters', 'visuals'})) {
      return null;
    }
    final id = r.raw('id'), title = r.raw('title');
    final rawVisuals = r.raw('visuals') ?? const <Object?>[];
    final filters = biReportFilters(r.raw('filters'));
    if (id is! String || !biReportId.hasMatch(id)) return null;
    if (title is! String || title.isEmpty || title.length > 80) return null;
    if (filters == null || rawVisuals is! List) return null;
    final visuals = <BiReportVisual>[];
    for (final v in rawVisuals) {
      final visual = BiReportVisual.fromJson(v);
      if (visual == null) return null;
      visuals.add(visual);
    }
    return BiReportPage(
      id: id,
      title: title,
      filters: filters,
      visuals: visuals,
    );
  }
}

/// The period of a report: relative to the workspace clock or fixed.
class BiReportPeriod {
  const BiReportPeriod.relative(this.grain, this.offset) : at = null;
  const BiReportPeriod.fixed(this.grain, String this.at) : offset = null;

  final BiGrain grain;
  final int? offset;
  final String? at;

  Map<String, Object> toJson() => {
    'mode': at == null ? 'relative' : 'fixed',
    'grain': grain.name,
    'at': ?at,
    if (at == null) 'offset': offset!,
  };

  /// The address parameters of the period (see [BiQueryContext.toQuery]).
  Map<String, String> toQuery() => {
    if (grain != BiGrain.month) 'grain': grain.name,
    if (at != null)
      'at': at!
    else if (offset != 0)
      'at': '$offset',
  };

  static BiReportPeriod of(BiQueryContext q) {
    final fixed = q.period.fixed;
    return fixed != null
        ? BiReportPeriod.fixed(q.grain, fixed.wire)
        : BiReportPeriod.relative(q.grain, q.period.offset ?? 0);
  }

  static BiReportPeriod? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null) return null;
    final grain = BiGrain.values
        .where((g) => g.name == r.raw('grain'))
        .firstOrNull;
    if (grain == null) return null;
    switch (r.raw('mode')) {
      case 'relative':
        final o = r.raw('offset');
        if (!biReportOnly(r, const {'mode', 'grain', 'offset'})) return null;
        return o is int && o >= -999 && o <= 999
            ? BiReportPeriod.relative(grain, o)
            : null;
      case 'fixed':
        final a = r.raw('at');
        if (!biReportOnly(r, const {'mode', 'grain', 'at'})) return null;
        return a is String && BiPeriod.parse(grain, a) != null
            ? BiReportPeriod.fixed(grain, a)
            : null;
    }
    return null;
  }
}

class BiPrintStyle {
  const BiPrintStyle({
    this.paper = 'A4',
    this.orientation = 'portrait',
    this.showSources = true,
  });

  final String paper;
  final String orientation;
  final bool showSources;

  static const papers = {'A4', 'Letter'};
  static const orientations = {'portrait', 'landscape'};

  Map<String, Object> toJson() => {
    'paper': paper,
    'orientation': orientation,
    'showSources': showSources,
  };

  static BiPrintStyle? fromJson(Object? raw) {
    if (raw == null) return const BiPrintStyle();
    final r = biReportReader(raw);
    if (r == null ||
        !biReportOnly(r, const {'paper', 'orientation', 'showSources'})) {
      return null;
    }
    final p = r.raw('paper') ?? 'A4';
    final o = r.raw('orientation') ?? 'portrait';
    final s = r.raw('showSources') ?? true;
    if (!papers.contains(p) || !orientations.contains(o) || s is! bool) {
      return null;
    }
    return BiPrintStyle(
      paper: p as String,
      orientation: o as String,
      showSources: s,
    );
  }
}

class BiReportDefinition {
  const BiReportDefinition({
    required this.period,
    required this.pages,
    this.filters = const [],
    this.printStyle = const BiPrintStyle(),
  });

  final BiReportPeriod period;
  final List<BiReportPage> pages;
  final List<BiReportFilter> filters;
  final BiPrintStyle printStyle;

  static const version = 2;
  static const maxPages = 4;
  static const maxVisuals = 24;

  /// The largest report the server stores (64 KB) and reads back.
  static const maxBytes = 65536;
  static const _keys = {'v', 'reportFilters', 'period', 'pages', 'printStyle'};

  /// A v1 question as one virtual page of KPI visuals, one per card in
  /// [cards] order. Nothing is written until the person saves a copy.
  factory BiReportDefinition.standard({
    required BiQueryContext query,
    required List<String> cards,
    required String pageTitle,
  }) => BiReportDefinition(
    period: BiReportPeriod.of(query),
    pages: [
      BiReportPage(
        id: 'p1',
        title: pageTitle,
        visuals: [
          for (final (i, c) in cards.indexed)
            BiReportVisual(
              id: 'v${i + 1}',
              type: BiVisualType.kpi,
              metricId: c,
              layout: BiVisualLayout(order: i),
            ),
        ],
      ),
    ],
  );

  /// The module ids of the first page, in reading order.
  List<String> get firstPageCards => [
    for (final v in pages.first.visuals.toList()..sort(_byOrder)) ?v.metricId,
  ];

  /// The address parameters of the report's period and first page.
  BiQueryContext? get query => BiQueryContext.tryParse(
    period.toQuery(),
  )?.copyWith(cards: firstPageCards);

  BiReportDefinition withFirstPage(BiReportPage page) => BiReportDefinition(
    period: period,
    pages: [page, ...pages.skip(1)],
    filters: filters,
    printStyle: printStyle,
  );

  Map<String, Object> toJson() => {
    'v': version,
    'reportFilters': [for (final f in filters) f.toJson()],
    'period': period.toJson(),
    'pages': [for (final p in pages) p.toJson()],
    'printStyle': printStyle.toJson(),
  };

  /// Parses a stored v2 definition; null when it is not one this client
  /// understands. Untrusted input: nothing is guessed, nothing is clamped.
  static BiReportDefinition? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null || r.raw('v') != version || !biReportOnly(r, _keys)) {
      return null;
    }
    final period = BiReportPeriod.fromJson(r.raw('period'));
    final rawPages = r.raw('pages');
    final filters = biReportFilters(r.raw('reportFilters'));
    final style = BiPrintStyle.fromJson(r.raw('printStyle'));
    if (period == null || filters == null || style == null) return null;
    if (rawPages is! List || rawPages.isEmpty || rawPages.length > maxPages) {
      return null;
    }
    final pages = <BiReportPage>[];
    for (final p in rawPages) {
      final page = BiReportPage.fromJson(p);
      if (page == null) return null;
      pages.add(page);
    }
    if (!_unique(pages)) return null;
    final report = BiReportDefinition(
      period: period,
      pages: pages,
      filters: filters,
      printStyle: style,
    );
    if (utf8.encode(jsonEncode(report.toJson())).length > maxBytes) return null;
    return report;
  }

  /// Ids are unique across pages and visuals, reading orders within a page,
  /// and the whole report stays within [maxVisuals].
  static bool _unique(List<BiReportPage> pages) {
    final ids = <String>{};
    var visuals = 0;
    for (final p in pages) {
      if (!ids.add(p.id)) return false;
      final orders = <int>{};
      for (final v in p.visuals) {
        visuals++;
        if (!ids.add(v.id) || !orders.add(v.layout.order)) return false;
      }
    }
    return visuals <= maxVisuals;
  }

  static int _byOrder(BiReportVisual a, BiReportVisual b) =>
      a.layout.order.compareTo(b.layout.order);
}
