// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2580 — the report editor's immutable commands and history: a report of
// two pages with a capacity figure, a floor bar and a finance table is built,
// moved, resized, duplicated and deleted; every step undoes and redoes; ids
// stay with their visuals and the reading order stays 0..n-1; the space's
// limits stop an addition; a choice the figure cannot keep is refused and
// the visual keeps its previous valid binding; filters only narrow; a style
// is presentation only and round-trips; the overview layout's moves.
import 'dart:convert';

import 'package:deskilo/features/workspace/application/report_editor/bi_report_commands.dart';
import 'package:deskilo/features/workspace/application/report_editor/bi_report_editor_state.dart';
import 'package:deskilo/features/workspace/domain/bi_overview_layout.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_limits.dart';
import 'package:deskilo/features/workspace/domain/bi_report_rules.dart';
import 'package:deskilo/features/workspace/domain/bi_saved_view.dart';
import 'package:flutter_test/flutter_test.dart';

const _capacity = 'capacity.seat_utilisation';
const _invoiced = 'finance.invoiced';
const _memberships = 'people.active_memberships_current';

BiReportDefinition _empty() => const BiReportDefinition(
  period: BiReportPeriod.relative(BiGrain.month, 0),
  pages: [BiReportPage(id: 'p1', title: 'Page 1')],
);

BiSavedView _view(BiReportDefinition report) => BiSavedView(
  id: 'view-1',
  scope: BiViewScope.private,
  name: 'Mine',
  definition: BiViewDefinition.ofReport(report),
  isDefault: false,
  revision: 1,
  mine: true,
);

/// Applies [edit] to [state], failing loudly when it was refused.
BiEditorState _apply(
  BiEditorState state,
  BiEdit Function(BiReportDefinition r, int p) edit,
) {
  final next = state.applied(edit(state.report, state.page));
  expect(next.refusal, isNull, reason: 'refused: ${next.refusal}');
  expect(next.binding, isNull, reason: 'unbound: ${next.binding}');
  return next;
}

List<String> _ids(BiReportPage page) => [
  for (final v in [
    ...page.visuals,
  ]..sort((a, b) => a.layout.order.compareTo(b.layout.order)))
    v.id,
];

void main() {
  group('building a two-page report', () {
    late BiEditorState s;

    setUp(() {
      s = BiEditorState.of(_view(_empty()));
      s = _apply(
        s,
        (r, p) => biAddVisual(r, p, BiVisualType.kpi, metricId: _capacity),
      );
      s = _apply(
        s,
        (r, p) => biAddVisual(r, p, BiVisualType.bar, metricId: _capacity),
      );
      s = _apply(s, (r, _) => biAddPage(r, 'Finance'));
      s = _apply(
        s,
        (r, p) => biAddVisual(r, p, BiVisualType.table, metricId: _invoiced),
      );
    });

    test('ids are minted once, unique over pages and visuals', () {
      expect(s.report.pages.map((p) => p.id), ['p1', 'p2']);
      expect(_ids(s.report.pages[0]), ['v1', 'v2']);
      expect(_ids(s.report.pages[1]), ['v3']);
      expect(s.page, 1, reason: 'a new page is the page shown');
      // A bar takes the figure's grouping, from a zero baseline.
      final bar = s.report.pages[0].visuals.firstWhere((v) => v.id == 'v2');
      expect(bar.dimension, 'level');
      expect(bar.style.axis, 'zero');
      // The stored text parses back to the same report.
      final again = BiReportDefinition.fromJson(
        jsonDecode(jsonEncode(s.report.toJson())),
      );
      expect(jsonEncode(again!.toJson()), jsonEncode(s.report.toJson()));
    });

    test('move, resize, duplicate, delete; each undoes and redoes', () {
      s = s.shown(page: 0);
      final steps = <BiEdit Function(BiReportDefinition, int)>[
        (r, p) => biMoveVisualBy(r, p, 'v2', -1),
        (r, p) => biResizeVisual(r, p, 'v1', span: 3, height: 2),
        (r, p) => biDuplicateVisual(r, p, id: 'v2'),
        (r, p) => biDeleteVisual(r, p, 'v1'),
      ];
      final reports = [s.report];
      for (final step in steps) {
        s = _apply(s, step);
        reports.add(s.report);
      }
      expect(_ids(s.report.pages[0]), ['v2', 'v4']);
      final copy = s.report.pages[0].visuals.firstWhere((v) => v.id == 'v4');
      final original = s.report.pages[0].visuals.firstWhere(
        (v) => v.id == 'v2',
      );
      expect(copy.metricId, original.metricId);
      expect(copy.dimension, original.dimension);
      expect(
        [for (final v in s.report.pages[0].visuals) v.layout.order]..sort(),
        [0, 1],
      );
      for (var i = steps.length - 1; i >= 0; i--) {
        s = s.undone();
        expect(jsonEncode(s.report.toJson()), jsonEncode(reports[i].toJson()));
      }
      expect(s.canUndo, isTrue, reason: 'the building steps remain');
      for (var i = 1; i <= steps.length; i++) {
        s = s.redone();
        expect(jsonEncode(s.report.toJson()), jsonEncode(reports[i].toJson()));
      }
      expect(s.canRedo, isFalse);
    });

    test('a resize stays on the grid', () {
      s = s.shown(page: 0);
      s = _apply(s, (r, p) => biResizeVisual(r, p, 'v1', span: 99, height: -9));
      final v = s.report.pages[0].visuals.firstWhere((v) => v.id == 'v1');
      expect(v.layout.span, BiVisualLayout.maxSpan);
      expect(v.layout.height, 1);
    });

    test('pages move, are renamed, and the last one stays', () {
      s = _apply(s, (r, _) => biMovePage(r, 1, -1));
      expect(s.report.pages.map((p) => p.id), ['p2', 'p1']);
      expect(s.page, 0, reason: 'the moved page stays on screen');
      s = _apply(s, (r, p) => biRenamePage(r, p, 'Money'));
      expect(s.report.pages.first.title, 'Money');
      s = _apply(s, (r, _) => biDeletePage(r, 0));
      final last = s.applied(biDeletePage(s.report, 0));
      expect(last.refusal, BiEditRefusal.lastPage);
      expect(last.report.pages, hasLength(1));
    });

    test('a dirty draft is what differs from the saved report', () {
      final clean = BiEditorState.of(_view(s.report));
      expect(clean.dirty, isFalse);
      expect(
        clean.applied(biRenamePage(clean.report, 0, 'Other')).dirty,
        isTrue,
      );
      expect(clean.withName('Renamed').dirty, isTrue);
    });
  });

  group('the space limits stop an addition', () {
    test('no visual past bi.report_max_visuals, no page past _pages', () {
      const limits = BiReportLimits(maxPages: 1, maxVisuals: 1);
      var s = BiEditorState.of(_view(_empty()));
      s = _apply(
        s,
        (r, p) => biAddVisual(
          r,
          p,
          BiVisualType.kpi,
          metricId: _capacity,
          limits: limits,
        ),
      );
      final more = s.applied(
        biAddVisual(
          s.report,
          0,
          BiVisualType.kpi,
          metricId: _capacity,
          limits: limits,
        ),
      );
      expect(more.refusal, BiEditRefusal.limit);
      expect(more.report.pages.first.visuals, hasLength(1));
      expect(
        s
            .applied(biDuplicateVisual(s.report, 0, id: 'v1', limits: limits))
            .refusal,
        BiEditRefusal.limit,
      );
      expect(
        s.applied(biAddPage(s.report, 'Two', limits: limits)).refusal,
        BiEditRefusal.limit,
      );
    });
  });

  group('a binding the figure cannot keep is refused', () {
    BiReportVisual kpi(String metric) => BiReportVisual.kpi(
      id: 'v1',
      metricId: metric,
      layout: const BiVisualLayout(order: 0),
    );

    test('a line needs a history; a stacked bar an additive figure', () {
      expect(
        biSetType(kpi(_memberships), BiVisualType.line).refusal,
        BiBindingRefusal.noHistory,
      );
      expect(
        biSetType(kpi(_capacity), BiVisualType.stackedBar).refusal,
        BiBindingRefusal.notAdditive,
      );
      expect(
        biSetType(kpi(_invoiced), BiVisualType.bar).refusal,
        BiBindingRefusal.noGrouping,
      );
      expect(biSetType(kpi(_capacity), BiVisualType.line).visual, isNotNull);
    });

    test('a percentage stays a percentage, an amount an amount', () {
      expect(
        biSetFormat(kpi(_capacity), 'currency').refusal,
        BiBindingRefusal.formatUnit,
      );
      expect(biSetFormat(kpi(_capacity), 'percent').visual?.format, 'percent');
      expect(
        biSetFormat(kpi(_invoiced), 'percent').refusal,
        BiBindingRefusal.formatUnit,
      );
    });

    test('rebinding keeps the old binding when the new figure cannot', () {
      var s = BiEditorState.of(_view(_empty()));
      s = _apply(
        s,
        (r, p) => biAddVisual(r, p, BiVisualType.bar, metricId: _capacity),
      );
      final before = jsonEncode(s.report.toJson());
      final refused = s.applied(
        biChangeVisual(s.report, 0, 'v1', (v) => biBindMetric(v, _invoiced)),
      );
      expect(refused.binding, BiBindingRefusal.noGrouping);
      expect(jsonEncode(refused.report.toJson()), before);
      expect(refused.canUndo, s.canUndo, reason: 'no step was recorded');
    });

    test('an unsupported grouping, a value sort without groups, a fit axis '
        'on a bar', () {
      expect(
        biSetDimension(kpi(_invoiced), 'level').refusal,
        BiBindingRefusal.dimensionUnsupported,
      );
      expect(
        biSetSort(kpi(_capacity), 'value_desc').refusal,
        BiBindingRefusal.sortNeedsGrouping,
      );
      final bar = biSetType(kpi(_capacity), BiVisualType.bar).visual!;
      expect(
        biSetStyle(bar, 'axis', 'fit').refusal,
        BiBindingRefusal.axisNeedsLine,
      );
      final line = biSetType(kpi(_capacity), BiVisualType.line).visual!;
      expect(biSetStyle(line, 'axis', 'fit').visual?.style.axis, 'fit');
    });
  });

  group('filters only narrow', () {
    BiReportDefinition withReportFilter() => BiReportDefinition(
      period: const BiReportPeriod.relative(BiGrain.month, 0),
      filters: const [BiReportFilter('level', 'in', 'a,b')],
      pages: [_empty().pages.first],
    );

    test('a page filter inside the report filter is kept', () {
      final edit = biAddPageFilter(
        withReportFilter(),
        0,
        const BiReportFilter('level', 'eq', 'a'),
      );
      expect(edit.report!.pages.first.filters.single.value, 'a');
    });

    test('a page filter outside it is refused, never an override', () {
      final edit = biAddPageFilter(
        withReportFilter(),
        0,
        const BiReportFilter('level', 'eq', 'c'),
      );
      expect(edit.refusal, BiEditRefusal.widens);
    });

    test('removing a filter', () {
      final edit = biRemoveFilter(withReportFilter(), null, 0);
      expect(edit.report!.filters, isEmpty);
      expect(
        biRemoveFilter(withReportFilter(), null, 5).refusal,
        BiEditRefusal.missing,
      );
    });
  });

  group('a style is presentation only', () {
    test('it round-trips, a default style is not written', () {
      final v = BiReportVisual.kpi(
        id: 'v1',
        metricId: _capacity,
        layout: const BiVisualLayout(order: 0),
      );
      expect(v.toJson().containsKey('style'), isFalse);
      final styled = biSetStyle(v, 'title', 'Seats').visual!;
      final back = BiReportVisual.fromJson(
        jsonDecode(jsonEncode(styled.toJson())),
      )!;
      expect(back.style.title, 'Seats');
      expect(back.metricId, v.metricId, reason: 'the figure is unchanged');
    });

    test('an unknown key, a palette outside the list, two lines: refused', () {
      for (final style in [
        {'colour': '#ff0000'},
        {'palette': 'neon'},
        {'title': 'two\nlines'},
        {'title': ''},
        {'legend': 'no'},
      ]) {
        expect(BiVisualStyle.fromJson(style), isNull, reason: '$style');
      }
    });
  });

  group('the overview layout', () {
    test('pin, unpin and move keep each figure once', () {
      var tiles = <String>['a', 'b'];
      tiles = biPinTile(tiles, 'c');
      tiles = biPinTile(tiles, 'a');
      expect(tiles, ['a', 'b', 'c']);
      tiles = biMoveTile(tiles, 'c', -2);
      expect(tiles, ['c', 'a', 'b']);
      expect(biMoveTile(tiles, 'c', -1), tiles, reason: 'out of range');
      expect(biUnpinTile(tiles, 'a'), ['c', 'b']);
    });

    test('the layout is the reader\'s own page-overview report', () {
      final report = biOverviewReport([_invoiced, _capacity], title: 'O');
      BiSavedView view({required bool mine}) => BiSavedView(
        id: mine ? 'mine' : 'theirs',
        scope: BiViewScope.private,
        name: 'O',
        definition: BiViewDefinition.ofReport(report),
        isDefault: false,
        revision: 1,
        mine: mine,
      );
      expect(biOverviewLayoutOf([view(mine: false)]), isNull);
      final mine = biOverviewLayoutOf([view(mine: false), view(mine: true)]);
      expect(mine?.id, 'mine');
      expect(biTilesOf(mine!.definition!.report!), [_invoiced, _capacity]);
      expect(
        biOverviewLayoutOf([_view(_empty())]),
        isNull,
        reason: 'an ordinary report is not a layout',
      );
    });
  });
}
