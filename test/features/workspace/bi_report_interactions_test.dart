// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2580 — what a selection on a report page does to the other visuals:
// picking floor A on a floor bar filters the compatible visuals of the SAME
// page to floor A, once (no cascade, no cycle); a figure that is not grouped
// by floor is left whole and says why; a text is never filtered; a selection
// outside a visual's own filters is refused, never an override; a selection
// is only taken from a visual that filters, on a named group. A filtered
// ratio is a ratio of sums — 10/100 and 10/20 make 20/120 — and an unknown
// part leaves the whole unknown, never a smaller number.
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_report_definition.dart';
import 'package:deskilo/features/workspace/domain/bi_report_selection.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const _capacity = 'capacity.seat_utilisation';
const _invoiced = 'finance.invoiced';

BiReportVisual _visual(
  String id,
  int order, {
  String metric = _capacity,
  BiVisualType type = BiVisualType.kpi,
  String? dimension,
  String interaction = 'filter',
  List<BiReportFilter> filters = const [],
}) => BiReportVisual(
  id: id,
  type: type,
  metricId: type == BiVisualType.text ? null : metric,
  dimension: dimension,
  filters: filters,
  layout: BiVisualLayout(order: order),
  interaction: interaction,
  text: type == BiVisualType.text ? 'About the floors' : null,
);

final _bar = _visual('bar', 0, type: BiVisualType.bar, dimension: 'level');
final _figure = _visual('figure', 1);
final _finance = _visual('finance', 2, metric: _invoiced);
final _text = _visual('text', 3, type: BiVisualType.text);
final _line = _visual('line', 4, type: BiVisualType.line);
final _floorB = _visual(
  'floor-b',
  5,
  filters: const [BiReportFilter('level', 'eq', 'b')],
);

final _page = BiReportPage(
  id: 'p1',
  title: 'Floors',
  visuals: [_bar, _figure, _finance, _text, _line, _floorB],
);
final _report = BiReportDefinition(
  period: const BiReportPeriod.relative(BiGrain.month, 0),
  pages: [_page],
);

BiRow _row(String key, num n, num d, {Set<KpiQuality> quality = const {}}) =>
    BiRow(
      key: key,
      label: 'Floor $key',
      current: BiMeasure(numerator: n, denominator: d, quality: quality),
    );

void main() {
  final floorA = biSelectionOf(_page, _bar, _row('a', 10, 100))!;

  test('a group picked on a bar that filters is the selection', () {
    expect(floorA.dimension, 'level');
    expect(floorA.key, 'a');
    expect(floorA.label, 'Floor a');
    expect(floorA.filter.toJson(), {
      'dimension': 'level',
      'operator': 'eq',
      'value': 'a',
    });
  });

  test('no selection from a visual that does not filter, or a total', () {
    final quiet = _visual(
      'quiet',
      0,
      type: BiVisualType.bar,
      dimension: 'level',
      interaction: 'none',
    );
    expect(biSelectionOf(_page, quiet, _row('a', 1, 2)), isNull);
    expect(biSelectionOf(_page, _figure, _row('a', 1, 2)), isNull);
    expect(
      biSelectionOf(
        _page,
        _bar,
        const BiRow(
          key: BiRow.totalKey,
          label: null,
          current: BiMeasure(numerator: 1),
        ),
      ),
      isNull,
    );
  });

  test('what floor A does to each visual of the page', () {
    BiCrossFilter effect(BiReportVisual v) =>
        biCrossFilterOf(_report, _page, v, floorA);
    expect(effect(_bar), BiCrossFilter.source);
    expect(effect(_figure), BiCrossFilter.filtered);
    expect(
      effect(_finance),
      BiCrossFilter.unsupported,
      reason: 'an unsupported finance grouping is refused, explicitly',
    );
    expect(effect(_text), BiCrossFilter.unaffected);
    expect(effect(_line), BiCrossFilter.unsupported);
    expect(
      effect(_floorB),
      BiCrossFilter.outsideScope,
      reason: 'a selection never widens a visual\'s own filter',
    );
  });

  test('a filtered figure reads its groups and keeps only floor A', () {
    final scope = _report.scopeOf(_page, _figure, selection: [floorA.filter])!;
    final plan = biReadPlanOf(_figure, scope);
    expect(plan.groupBy, 'level');
    expect(plan.applied.single.value, 'a');
    expect(plan.unapplied, isEmpty);
    final finance = biReadPlanOf(
      _finance,
      _report.scopeOf(_page, _finance, selection: [floorA.filter])!,
    );
    expect(finance.groupBy, isNull);
    expect(finance.unapplied, hasLength(1), reason: 'said, not pretended');
  });

  test('a ratio over groups is a ratio of sums: 10/100 + 10/20 = 20/120', () {
    final result = BiResult(
      period: const BiPeriod(BiGrain.month, 2026, 3),
      total: _row(BiRow.totalKey, 20, 120),
      groups: [_row('a', 10, 100), _row('b', 10, 20), _row('c', 5, 5)],
      computedAt: DateTime(2026, 3, 15),
    );
    final both = biRowsIn(result, const [BiReportFilter('level', 'in', 'a,b')]);
    final total = biTotalOf(both);
    expect(total.current.numerator, 20);
    expect(total.current.denominator, 120);
    expect(
      total.current.value(KpiAggregation.ratioOfSums),
      closeTo(20 / 120, 1e-9),
    );
    expect(biRowsIn(result, const [BiReportFilter('level', 'neq', 'c')]), [
      result.groups[0],
      result.groups[1],
    ]);
  });

  test('an unknown part leaves the whole unknown; no group is not zero', () {
    final total = biTotalOf([
      _row('a', 10, 100),
      _row('b', 0, 0, quality: {KpiQuality.unavailable}),
    ]);
    expect(total.current.quality, contains(KpiQuality.unavailable));
    expect(
      biTotalOf(const []).current.quality,
      contains(KpiQuality.notApplicable),
    );
  });

  test('a selection is never part of the saved report', () {
    final json = _report.toJson().toString();
    expect(json.contains("'a'"), isFalse);
  });
}
