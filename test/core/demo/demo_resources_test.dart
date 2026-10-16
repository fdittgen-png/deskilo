// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — the demo twin shows a meeting room booked by the hour beside a
// seat booked for the day, and a garage whose electric slot has its charger.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/core/demo/seed/demo_resource_seed.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = DemoFixture.build();

  test('the flags of both kinds are on in the demo', () {
    expect(demoFeatureFlags['meetingRooms'], isTrue);
    expect(demoFeatureFlags['parking'], isTrue);
  });

  test('the boardroom is an hourly room booked 10:00-11:00 while a seat is '
      'booked for the day', () {
    final room = fixture.floorPlan.seats.singleWhere(
      (s) => s.id == DemoResources.boardroom,
    );
    expect(room.resourceKind, ResourceKind.room);
    expect(room.capacity, 8);
    expect(room.slotMinutes, 60);
    final all = fixture.reservations.reservations;
    final hour = all.singleWhere((r) => r.id == 'demo-boardroom-today');
    expect(hour.endsAt.difference(hour.startsAt), const Duration(hours: 1));
    final seatDay = all.singleWhere((r) => r.id == 'demo-today');
    expect(seatDay.startsAt.isBefore(hour.startsAt), isTrue);
    expect(seatDay.endsAt.isAfter(hour.endsAt), isTrue);
    expect(
      fixture.floorPlan.seats
          .singleWhere((s) => s.id == seatDay.seatId)
          .resourceKind,
      ResourceKind.seat,
    );
  });

  test('the garage holds a standard, an electric and an accessible slot; '
      'only the electric one has a charger', () {
    final garage = fixture.floorPlan.offices.singleWhere(
      (o) => o.id == 'demo-office-garage',
    );
    expect(garage.areaKind, AreaKind.parking);
    final slots = fixture.floorPlan.seats
        .where((s) => s.resourceKind == ResourceKind.parking)
        .toList();
    expect(slots.map((s) => s.parkingKind), [
      ParkingKind.standard,
      ParkingKind.ev,
      ParkingKind.accessible,
    ]);
    expect(slots.every((s) => s.slotMinutes == 1440), isTrue);
    expect(fixture.chargingStations.stations.keys, [DemoResources.slotEv]);
    expect(fixture.chargingStations.stations.values.single.powerKw, 22);
  });
}
