// SPDX-License-Identifier: AGPL-3.0-or-later
// The same decoder and arithmetic used by the dashboard must never turn
// missing, non-finite or unqualified data into a measured zero or a trend.
import 'package:deskilo/features/workspace/domain/bi_result.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> answer() => {
  'from': '2026-10-01T00:00:00Z',
  'to': '2026-11-01T00:00:00Z',
  'physical_seat_hours': 100,
  'offered_seat_hours': 80,
  'reserved_seat_hours': 20,
  'reserved_outside_offered_seat_hours': 0,
  'overlapping_seat_hours': 0,
  'seats': 10,
  'rooms_without_seats': 0,
  'offered_room_hours': 0,
  'reserved_room_hours': 0,
  'quality': <String>[],
  'reasons': <String>[],
  'computed_at': '2026-10-03T12:00:00Z',
};

void main() {
  for (final bad in [null, 'not a number', 'NaN', 'Infinity', -1]) {
    test('invalid reserved hours $bad cannot become a valid KPI', () {
      final json = answer()..['reserved_seat_hours'] = bad;
      expect(() => seatCapacityFromJson(json), throwsFormatException);
    });
  }

  test('missing capacity and invalid count or interval are refused', () {
    expect(
      () => seatCapacityFromJson(answer()..remove('offered_seat_hours')),
      throwsFormatException,
    );
    expect(
      () => seatCapacityFromJson(answer()..['seats'] = 1.5),
      throwsFormatException,
    );
    expect(
      () => seatCapacityFromJson(answer()..['to'] = answer()['from']),
      throwsFormatException,
    );
  });

  test('a newer unrecognised quality flag cannot disappear', () {
    final k = seatCapacityFromJson(answer()..['quality'] = ['suppressed']);
    expect(k.quality, contains(KpiQuality.unavailable));
    expect(k.utilisation, isNull);
  });

  for (final quality in [
    KpiQuality.notRecorded,
    KpiQuality.notApplicable,
    KpiQuality.unavailable,
    KpiQuality.forbidden,
  ]) {
    test('$quality cannot display supplied numbers', () {
      final wire = switch (quality) {
        KpiQuality.notRecorded => 'not_recorded',
        KpiQuality.notApplicable => 'not_applicable',
        _ => quality.name,
      };
      final k = seatCapacityFromJson(answer()..['quality'] = [wire]);
      expect(k.utilisation, isNull);
      expect(
        BiMeasure(
          numerator: 20,
          denominator: 80,
          quality: {quality},
        ).value(KpiAggregation.ratioOfSums),
        isNull,
      );
    });
  }

  test('stale or partial figures are not a qualified performance change', () {
    for (final quality in [KpiQuality.partial, KpiQuality.stale]) {
      final row = BiRow(
        key: 'total',
        label: null,
        current: BiMeasure(numerator: 20, denominator: 80, quality: {quality}),
        compared: const BiMeasure(numerator: 10, denominator: 80),
      );
      expect(changeOf(row, KpiAggregation.ratioOfSums).undefined, isTrue);
    }
  });

  test('invalid denominators and non-finite values stay undefined', () {
    expect(ratioOfSums([(numerator: 1, denominator: -2)]), isNull);
    expect(ratioOfSums([(numerator: double.nan, denominator: 2)]), isNull);
    expect(
      const BiMeasure(numerator: double.infinity).value(KpiAggregation.sum),
      isNull,
    );
  });
}
