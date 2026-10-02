// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1918 — the KPI contract: ratios are sums over sums, a zero
// denominator is undefined, and the server's answer parses into the same
// numbers an independent count gives.
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a ratio is sum(numerator) / sum(denominator), never a mean of '
      'ratios', () {
    final r = ratioOfSums([
      (numerator: 10, denominator: 100),
      (numerator: 10, denominator: 20),
    ]);
    expect(r, closeTo(20 / 120, 1e-12));
    expect(r, isNot(closeTo((0.1 + 0.5) / 2, 1e-6)));
  });

  test('a zero denominator is undefined, not 0 %', () {
    expect(ratioOfSums([(numerator: 0, denominator: 0)]), isNull);
    expect(ratioOfSums(const []), isNull);
  });

  test('the catalogue names each KPI once, with its whole definition', () {
    expect({
      for (final k in kpiCatalogue) k.id,
    }, hasLength(kpiCatalogue.length));
    expect(seatUtilisationKpi.aggregation, KpiAggregation.ratioOfSums);
    expect(seatUtilisationKpi.numerator, 'reserved_seat_hours');
    expect(seatUtilisationKpi.denominator, 'offered_seat_hours');
    expect(seatUtilisationKpi.permission, 'manageReservations');
  });

  test("the server's answer for the issue's fixture: 10 seats x 8 h, two "
      'seats blocked 2 h, a whole 4-seat desk for 2 h plus two single '
      'seat-hours', () {
    final kpi = seatCapacityFromJson(const {
      'from': '2026-10-05T00:00:00+02:00',
      'to': '2026-10-06T00:00:00+02:00',
      'seats': 10,
      'physical_seat_hours': 80.00,
      'offered_seat_hours': 76.00,
      'reserved_seat_hours': 10.00,
      'reserved_outside_offered_seat_hours': 1.00,
      'overlapping_seat_hours': 0,
      'rooms_without_seats': 1,
      'offered_room_hours': 8.0,
      'reserved_room_hours': '3.00',
      'quality': ['partial', 'from_a_newer_server'],
      'reasons': ['current_plan_and_hours'],
      'computed_at': '2026-10-01T10:00:00Z',
    });
    expect(kpi.offeredSeatHours, 76);
    expect(kpi.utilisation, closeTo(10 / 76, 1e-12));
    expect(kpi.reservedRoomHours, 3);
    expect(kpi.quality, {
      KpiQuality.partial,
    }, reason: 'an unknown quality word is ignored, not guessed');
  });

  test('nothing offered: the utilisation is undefined', () {
    final kpi = seatCapacityFromJson(const {
      'from': '2026-10-05T00:00:00Z',
      'to': '2026-10-06T00:00:00Z',
      'offered_seat_hours': 0,
      'reserved_seat_hours': 0,
      'quality': ['not_applicable'],
      'computed_at': '2026-10-01T10:00:00Z',
    });
    expect(kpi.utilisation, isNull);
    expect(kpi.quality, {KpiQuality.notApplicable});
  });
}
