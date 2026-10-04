// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Business analytics core: a series says what the data knows (a gap is
// a gap, never a zero), a change against a missing side is undefined, the
// run-rate applies only to an additive running period, the projection is a
// labelled estimate made only from enough complete periods, and shares add
// up to the whole or are not shown.
import 'package:deskilo/features/workspace/domain/bi_analysis.dart';
import 'package:deskilo/features/workspace/domain/bi_composition.dart';
import 'package:deskilo/features/workspace/domain/bi_query.dart';
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

BiPeriod _m(int year, int month) => BiPeriod(BiGrain.month, year, month);

BiSeries _months(List<num?> values, {bool lastRunning = true}) {
  // The last value is October 2026.
  final end = _m(2026, 10);
  return BiSeries([
    for (final (i, v) in values.indexed)
      BiSeriesPoint(
        period: end.shift(i - (values.length - 1)),
        value: v,
        partial: lastRunning && i == values.length - 1,
      ),
  ]);
}

BiRow _row(String key, num n, {Set<KpiQuality> q = const {}}) => BiRow(
  key: key,
  label: key,
  current: BiMeasure(numerator: n, quality: q),
);

void main() {
  group('series', () {
    test('finds the previous period and the same one a year ago', () {
      final s = _months([
        for (var i = 1; i <= 14; i++) i * 10,
      ], lastRunning: false);
      expect(s.current.period, _m(2026, 10));
      expect(s.previous!.period, _m(2026, 9));
      expect(s.yearAgo!.period, _m(2025, 10));
      expect(s.yearAgo!.value, 20);
    });

    test('a series too short has no year-ago period', () {
      final s = _months([1, 2, 3, 4]);
      expect(s.yearAgo, isNull);
    });

    test('history is the complete periods before the current one', () {
      final s = _months([10, null, 30, 40, 50]);
      expect(s.history.map((p) => p.value), [10, 30, 40]);
    });

    test('comparison bars: previous, year ago, then now', () {
      final s = _months([for (var i = 0; i < 13; i++) 100 + i]);
      expect(comparisonBars(s).map((b) => b.kind), [
        BiBarKind.previous,
        BiBarKind.yearAgo,
        BiBarKind.current,
      ]);
    });
  });

  group('change', () {
    test('an amount: absolute and relative', () {
      final c = changeBetween(150, 100, KpiAggregation.sum);
      expect(c.absolute, 50);
      expect(c.relative, closeTo(0.5, 1e-9));
      expect(directionOf(c), BiDirection.up);
    });

    test('a ratio: points', () {
      final c = changeBetween(0.40, 0.45, KpiAggregation.ratioOfSums);
      expect(c.points, closeTo(-5, 1e-9));
      expect(directionOf(c), BiDirection.down);
    });

    test('a missing side is undefined, never read as zero', () {
      expect(changeBetween(null, 100, KpiAggregation.sum).undefined, isTrue);
      expect(changeBetween(100, null, KpiAggregation.sum).undefined, isTrue);
      expect(
        directionOf(changeBetween(null, 100, KpiAggregation.sum)),
        BiDirection.unknown,
      );
    });

    test('a zero base has no relative change', () {
      final c = changeBetween(10, 0, KpiAggregation.sum);
      expect(c.relative, isNull);
      expect(c.absolute, 10);
    });

    test('within the tolerance it is flat', () {
      expect(
        directionOf(changeBetween(100.2, 100, KpiAggregation.sum)),
        BiDirection.flat,
      );
    });
  });

  group('run-rate of the running period', () {
    final from = DateTime(2026, 10);
    final to = DateTime(2026, 11);
    const running = BiSeriesPoint(
      period: BiPeriod(BiGrain.month, 2026, 10),
      value: 500,
      partial: true,
    );

    test('scales an additive figure to the whole period', () {
      final r = runRateOf(
        running,
        from: from,
        to: to,
        now: DateTime(2026, 10, 11, 12),
        aggregation: KpiAggregation.sum,
      );
      expect(r, isNotNull);
      expect(r!.elapsed, closeTo(10.5 / 31, 0.001));
      expect(r.projected, closeTo(500 / (10.5 / 31), 1));
    });

    test('a ratio does not accumulate: no run-rate', () {
      expect(
        runRateOf(
          running,
          from: from,
          to: to,
          now: DateTime(2026, 10, 11),
          aggregation: KpiAggregation.ratioOfSums,
        ),
        isNull,
      );
    });

    test('too early in the period says nothing', () {
      expect(
        runRateOf(
          running,
          from: from,
          to: to,
          now: DateTime(2026, 10, 2),
          aggregation: KpiAggregation.sum,
        ),
        isNull,
      );
    });

    test('a finished period has none', () {
      const done = BiSeriesPoint(period: BiPeriod(BiGrain.month, 2026, 10), value: 5);
      expect(
        runRateOf(
          done,
          from: from,
          to: to,
          now: DateTime(2026, 10, 20),
          aggregation: KpiAggregation.sum,
        ),
        isNull,
      );
    });
  });

  group('projection', () {
    test('follows a straight line and widens its range away from the data', () {
      final s = _months([for (var i = 1; i <= 9; i++) i * 100, 1000]);
      final f = forecastOf(s, aggregation: KpiAggregation.sum);
      expect(f, isNotNull);
      expect(f!.basis, 9);
      expect(f.slope, closeTo(100, 1e-6));
      expect(f.points, hasLength(3));
      expect(f.points.first.period, _m(2026, 11));
      // January..September are 100..900; the running October is not fitted,
      // so November lies two periods past the last complete one.
      expect(f.points.first.value, closeTo(1100, 1e-6));
      // A perfect line has no scatter: the range is the line itself.
      expect(f.points.first.high - f.points.first.low, closeTo(0, 1e-6));
    });

    test('noisy data gives a range that widens with distance', () {
      final noisy = [100, 140, 90, 160, 110, 170, 120, 180, 130, 999];
      final f = forecastOf(_months(noisy), aggregation: KpiAggregation.sum)!;
      final w1 = f.points[0].high - f.points[0].low;
      final w3 = f.points[2].high - f.points[2].low;
      expect(w1, greaterThan(0));
      expect(w3, greaterThan(w1));
    });

    test('too few complete periods: no projection', () {
      expect(forecastOf(_months([10, 20, 30, 999]), aggregation: KpiAggregation.sum), isNull);
    });

    test('the running period and gaps are not fitted', () {
      final s = _months([null, null, 10, 20, 30, 40, 5000]);
      final f = forecastOf(s, aggregation: KpiAggregation.sum)!;
      expect(f.basis, 4);
      expect(f.slope, closeTo(10, 1e-6));
    });

    test('an amount is never projected below zero', () {
      final s = _months([100, 80, 60, 40, 20, 5, 999]);
      final f = forecastOf(s, aggregation: KpiAggregation.sum)!;
      for (final p in f.points) {
        expect(p.value, greaterThanOrEqualTo(0));
        expect(p.low, greaterThanOrEqualTo(0));
      }
    });

    test('a ratio is never projected above one', () {
      final s = _months([0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.5]);
      final f = forecastOf(s, aggregation: KpiAggregation.ratioOfSums)!;
      for (final p in f.points) {
        expect(p.value, lessThanOrEqualTo(1));
        expect(p.high, lessThanOrEqualTo(1));
      }
    });
  });

  group('shares of a whole', () {
    String label(BiRow r) => r.label ?? r.key;

    test('largest first, adding up to one', () {
      final s = sharesOf(
        [_row('a', 10), _row('b', 30), _row('c', 60)],
        labelOf: label,
        otherLabel: 'Other',
      )!;
      expect(s.map((x) => x.key), ['c', 'b', 'a']);
      expect(s.fold<double>(0, (a, x) => a + x.share), closeTo(1, 1e-9));
      expect(s.first.share, closeTo(0.6, 1e-9));
    });

    test('the smallest parts fold into one other', () {
      final rows = [for (var i = 1; i <= 9; i++) _row('g$i', i)];
      final s = sharesOf(rows, labelOf: label, otherLabel: 'Other', maxItems: 4)!;
      expect(s, hasLength(5));
      expect(s.last.isOther, isTrue);
      expect(s.last.value, 1 + 2 + 3 + 4 + 5);
      expect(s.fold<double>(0, (a, x) => a + x.share), closeTo(1, 1e-9));
    });

    test('an unknown or negative part means no composition', () {
      expect(
        sharesOf(
          [_row('a', 10), _row('b', 5, q: {KpiQuality.notRecorded})],
          labelOf: label,
          otherLabel: 'Other',
        ),
        isNull,
      );
      expect(
        sharesOf([_row('a', 10), _row('b', -5)], labelOf: label, otherLabel: 'Other'),
        isNull,
      );
    });

    test('one group is not a composition', () {
      expect(sharesOf([_row('a', 10)], labelOf: label, otherLabel: 'Other'), isNull);
    });

    test('nothing in the groups: none', () {
      expect(
        sharesOf([_row('a', 0), _row('b', 0)], labelOf: label, otherLabel: 'Other'),
        isNull,
      );
    });
  });

  group('composition from the figures', () {
    SeatCapacityKpi kpi({
      double physical = 1000,
      double offered = 600,
      double reserved = 120,
      double outside = 0,
    }) => SeatCapacityKpi(
      from: DateTime(2026, 10),
      to: DateTime(2026, 11),
      physicalSeatHours: physical,
      offeredSeatHours: offered,
      reservedSeatHours: reserved,
      reservedOutsideOfferedSeatHours: outside,
      overlappingSeatHours: 0,
      seats: 5,
      roomsWithoutSeats: 0,
      offeredRoomHours: 0,
      reservedRoomHours: 0,
      quality: const {},
      reasons: const [],
      computedAt: DateTime(2026, 10, 4),
    );
    const labels = SeatTimeLabels(reserved: 'R', free: 'F', closed: 'C');

    test('reserved, free and closed add up to the physical hours', () {
      final parts = seatTimeComposition(kpi(), labels)!;
      expect(parts.map((p) => p.key), ['reserved', 'free', 'closed']);
      expect(parts.fold<num>(0, (a, p) => a + p.value), 1000);
      expect(parts.first.share, closeTo(0.12, 1e-9));
    });

    test('inconsistent figures show no composition', () {
      expect(seatTimeComposition(kpi(offered: 1200), labels), isNull);
      expect(seatTimeComposition(kpi(reserved: 700), labels), isNull);
    });

    test('collected of invoiced', () {
      final parts = collectionComposition(
        invoiced: 1000,
        collected: 250,
        collectedLabel: 'C',
        outstandingLabel: 'O',
      )!;
      expect(parts.map((p) => p.key), ['collected', 'outstanding']);
      expect(parts.first.share, closeTo(0.25, 1e-9));
    });

    test('more collected than invoiced is not a part of the whole', () {
      expect(
        collectionComposition(
          invoiced: 100,
          collected: 150,
          collectedLabel: 'C',
          outstandingLabel: 'O',
        ),
        isNull,
      );
      expect(
        collectionComposition(
          invoiced: null,
          collected: 10,
          collectedLabel: 'C',
          outstandingLabel: 'O',
        ),
        isNull,
      );
    });
  });
}
