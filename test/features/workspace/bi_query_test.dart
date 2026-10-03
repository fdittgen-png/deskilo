// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1923 B — the shared Web-BI query context, the comparison arithmetic
// and the module registry's conformance: every module the BI page can
// show declares a valid matrix, a view, and the KPI contract it reads.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/features/workspace/domain/bi_modules.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:deskilo/features/workspace/presentation/widgets/bi_module_section.dart';
import 'package:flutter_test/flutter_test.dart';

BiMeasure _m(num n, num? d, {Set<KpiQuality> q = const {}}) =>
    BiMeasure(numerator: n, denominator: d, quality: q);

void main() {
  group('the address', () {
    test('the standard context has no parameters, and round-trips', () {
      expect(BiQueryContext.standard.toQuery(), isEmpty);
      const asked = BiQueryContext(
        grain: BiGrain.quarter,
        period: BiPeriodRef.fixed(BiPeriod(BiGrain.quarter, 2026, 1)),
        comparison: BiComparison.custom,
        comparedWith: BiPeriod(BiGrain.quarter, 2025, 3),
        groupBy: 'level',
        sort: BiSort.valueDescending,
        view: BiView.chart,
      );
      expect(asked.toQuery(), {
        'grain': 'quarter',
        'at': '2026-Q1',
        'cmp': '2025-Q3',
        'by': 'level',
        'sort': 'value_desc',
        'view': 'chart',
      });
      expect(BiQueryContext.parse(asked.toQuery()), asked);
      expect(
        BiQueryContext.parse({'at': '-1', 'cmp': 'year'}),
        const BiQueryContext(
          period: BiPeriodRef.relative(-1),
          comparison: BiComparison.previousYear,
        ),
      );
    });

    test('a manipulated address is refused with every reason, never '
        'read as the standard query', () {
      Set<BiContextIssue> issues(Map<String, String> q) {
        try {
          BiQueryContext.parse(q);
        } on BiContextRefused catch (e) {
          return e.issues;
        }
        return const {};
      }

      expect(issues({'grain': 'week'}), {BiContextIssue.unknownGrain});
      expect(issues({'by': 'member', 'sort': 'random', 'view': 'pie'}), {
        BiContextIssue.unknownDimension,
        BiContextIssue.unknownSort,
        BiContextIssue.unknownView,
      });
      expect(issues({'at': '2026-13'}), {BiContextIssue.malformedPeriod});
      expect(issues({'grain': 'quarter', 'at': '2026-03'}), {
        BiContextIssue.malformedPeriod,
      }, reason: 'a month is not a quarter');
      expect(issues({'cmp': 'yesterday'}), {BiContextIssue.unknownComparison});
      expect(issues({'member': 'ws-1'}), {BiContextIssue.unknownParameter});
      expect(BiQueryContext.tryParse({'by': 'member'}), isNull);
    });
  });

  group('periods', () {
    test('relative periods resolve on the date they are opened; fixed ones '
        'never move', () {
      const lastMonth = BiQueryContext(period: BiPeriodRef.relative(-1));
      expect(lastMonth.current(DateTime(2026, 1, 15)).wire, '2025-12');
      expect(lastMonth.current(DateTime(2026, 3, 31)).wire, '2026-02');
      const march = BiQueryContext(
        period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2026, 3)),
      );
      expect(march.current(DateTime(2027, 8, 1)).wire, '2026-03');
    });

    test('quarters and years shift across the year boundary', () {
      const q1 = BiPeriod(BiGrain.quarter, 2026, 1);
      expect(q1.shift(-1).wire, '2025-Q4');
      expect(q1.shift(-4).wire, '2025-Q1');
      expect(q1.startMonth, 1);
      expect(const BiPeriod(BiGrain.quarter, 2026, 4).startMonth, 10);
      expect(q1.distanceTo(const BiPeriod(BiGrain.quarter, 2026, 3)), 2);
      expect(
        BiPeriod.containing(BiGrain.quarter, DateTime(2026, 8, 3)).wire,
        '2026-Q3',
      );
      expect(
        BiPeriod.containing(BiGrain.year, DateTime(2026, 8, 3)).wire,
        '2026',
      );
    });

    test('the compared period follows the comparison', () {
      final today = DateTime(2026, 3, 10);
      const c = BiQueryContext(comparison: BiComparison.previousPeriod);
      expect(c.compared(today)!.wire, '2026-02');
      expect(
        c.copyWith(comparison: BiComparison.previousYear).compared(today)!.wire,
        '2025-03',
      );
      expect(BiQueryContext.standard.compared(today), isNull);
    });

    test('changing the grain drops what belonged to the old grain', () {
      const c = BiQueryContext(
        period: BiPeriodRef.fixed(BiPeriod(BiGrain.month, 2026, 3)),
        comparison: BiComparison.custom,
        comparedWith: BiPeriod(BiGrain.month, 2025, 3),
      );
      final q = c.copyWith(grain: BiGrain.quarter);
      expect(q.period, const BiPeriodRef.relative(0));
      expect(q.comparison, BiComparison.previousPeriod);
      expect(q.comparedWith, isNull);
    });
  });

  group('the arithmetic', () {
    test('a ratio compares in percentage points; a zero base is undefined', () {
      final row = BiRow(
        key: 'total',
        label: null,
        current: _m(30, 100),
        compared: _m(20, 80),
      );
      expect(row.current.value(KpiAggregation.ratioOfSums), 0.3);
      expect(
        changeOf(row, KpiAggregation.ratioOfSums).points,
        closeTo(5, 1e-9),
      );
      expect(exposureDiffers(row), isTrue);
      final empty = BiRow(
        key: 'total',
        label: null,
        current: _m(30, 100),
        compared: _m(0, 0),
      );
      expect(changeOf(empty, KpiAggregation.ratioOfSums).undefined, isTrue);
    });

    test('an additive change has an absolute and a relative part; a zero '
        'base has no relative change', () {
      final c = changeOf(
        BiRow(
          key: 'k',
          label: 'x',
          current: _m(150, null),
          compared: _m(100, null),
        ),
        KpiAggregation.sum,
      );
      expect(c.absolute, 50);
      expect(c.relative, 0.5);
      final zero = changeOf(
        BiRow(
          key: 'k',
          label: 'x',
          current: _m(150, null),
          compared: _m(0, null),
        ),
        KpiAggregation.sum,
      );
      expect(zero.absolute, 150);
      expect(zero.relative, isNull);
    });

    test('an unrecorded period has no value and no change — never zero', () {
      final row = BiRow(
        key: 'total',
        label: null,
        current: _m(30, 100),
        compared: _m(0, 0, q: {KpiQuality.notRecorded}),
      );
      expect(row.compared!.value(KpiAggregation.sum), isNull);
      expect(changeOf(row, KpiAggregation.ratioOfSums).undefined, isTrue);
      expect(exposureDiffers(row), isFalse);
    });

    test('what no group explains is a remainder row, not lost', () {
      final rest = remainderOf(_m(50, 200), [_m(20, 80), _m(10, 70)]);
      expect(rest!.numerator, 20);
      expect(rest.denominator, 50);
      expect(rest.quality, {KpiQuality.partial});
      expect(remainderOf(_m(30, 150), [_m(20, 80), _m(10, 70)]), isNull);
      expect(
        remainderOf(_m(30, 150), [
          _m(0, 0, q: {KpiQuality.unavailable}),
        ]),
        isNull,
        reason: 'an unknown group cannot be subtracted',
      );
    });

    test('rows sort by value, undefined last', () {
      final rows = [
        BiRow(key: 'a', label: 'A', current: _m(1, 10)),
        BiRow(key: 'b', label: 'B', current: _m(0, 0)),
        BiRow(key: 'c', label: 'C', current: _m(5, 10)),
      ];
      List<String> keys(BiSort s) => [
        for (final r in sortRows(rows, s, KpiAggregation.ratioOfSums)) r.key,
      ];
      expect(keys(BiSort.valueDescending), ['c', 'a', 'b']);
      expect(keys(BiSort.valueAscending), ['a', 'c', 'b']);
      expect(keys(BiSort.natural), ['a', 'b', 'c']);
    });
  });

  group('registry conformance (every module)', () {
    for (final m in biModules) {
      test(m.id, () {
        expect(biModuleViews, contains(m.id), reason: 'a view');
        expect(m.grains, isNotEmpty);
        expect(m.comparisons, contains(BiComparison.none));
        expect(biDimensions.containsAll(m.groupings), isTrue);
        final kpi = kpiCatalogue.where((k) => k.id == m.id).firstOrNull;
        if (kpi != null) {
          expect(m.aggregation, kpi.aggregation);
          expect({
            for (final p in m.permissions) p.name,
          }, kpi.permissions.toSet());
          expect(kpi.dimensions.toSet().containsAll(m.groupings), isTrue);
        }
        if (m.drill case final d?) {
          expect(
            routeRules.any((r) => r.pattern == d.route),
            isTrue,
            reason: 'the drill-through opens a real route',
          );
        }
        expect(
          m.unsupported(const BiQueryContext(groupBy: 'level')),
          m.groupings.contains('level') ? isEmpty : {BiUnsupported.grouping},
        );
      });
    }
  });
}
