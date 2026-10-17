// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2631 — the demo twin of meeting rooms and parking: a boardroom booked by
// the hour beside a seat booked for the morning, and a garage with a
// standard, an electric (charger included) and an accessible slot, booked by
// the day. Every date follows the session's seeded instant.
import '../../../features/plan/domain/charging_station.dart';
import '../../../features/plan/domain/desk.dart';
import '../../../features/plan/domain/grid_geometry.dart';
import '../../../features/plan/domain/level.dart';
import '../../../features/plan/domain/office.dart';
import '../../../features/plan/domain/seat.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/floor_plan_repository.dart';
import '../data/plan_resource_repository.dart';
import '../data/reservation_repository.dart';
import '../demo_clock.dart';
import 'demo_space_seed.dart';

/// Ids the guides and the bookings below tell stories about.
abstract final class DemoResources {
  static const boardroom = 'demo-room-boardroom';
  static const parkingLevel = 'demo-level-parking';
  static const slotStandard = 'demo-slot-p1';
  static const slotEv = 'demo-slot-p2';
  static const slotAccessible = 'demo-slot-p3';
}

/// Adds the boardroom to the first floor and the garage on a level of its
/// own, the EV slot's charger, and today's bookings on them.
void seedDemoResources(
  FakeFloorPlanRepository plan,
  FakeChargingStationRepository chargers,
  FakeReservationRepository reservations,
  DateTime now,
) {
  _seedResourceLayout(plan, chargers);
  _seedResourceBookings(reservations, now);
}

void _seedResourceLayout(
  FakeFloorPlanRepository plan,
  FakeChargingStationRepository chargers,
) {
  const ws = 'ws-1';
  plan.levels.add(
    const Level(
      id: DemoResources.parkingLevel,
      workspaceId: ws,
      name: 'Parking',
      sortOrder: 2,
    ),
  );
  plan.offices.addAll(const [
    Office(
      id: 'demo-office-boardroom',
      workspaceId: ws,
      levelId: DemoSpace.firstFloor,
      name: 'Boardroom',
      color: 5,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 12, w: 14, h: 10),
    ),
    Office(
      id: 'demo-office-garage',
      workspaceId: ws,
      levelId: DemoResources.parkingLevel,
      name: 'Garage',
      color: 1,
      bookableAsWhole: false,
      rect: GridRect(x: 0, y: 0, w: 30, h: 10),
      areaKind: AreaKind.parking,
    ),
  ]);
  plan.desks.addAll(const [
    Desk(
      id: 'demo-desk-boardroom',
      workspaceId: ws,
      officeId: 'demo-office-boardroom',
      name: 'Boardroom table',
      rect: GridRect(x: 2, y: 14, w: 2 * SeatFootprint.length, h: 4),
    ),
    Desk(
      id: 'demo-desk-garage',
      workspaceId: ws,
      officeId: 'demo-office-garage',
      name: 'Bays',
      rect: GridRect(x: 2, y: 2, w: 3 * SeatFootprint.length, h: 4),
    ),
  ]);
  plan.seats.addAll(const [
    Seat(
      id: DemoResources.boardroom,
      workspaceId: ws,
      deskId: 'demo-desk-boardroom',
      name: 'Boardroom',
      x: 2,
      y: 14,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
      resourceKind: ResourceKind.room,
      capacity: 8,
      slotMinutes: 60,
    ),
    Seat(
      id: DemoResources.slotStandard,
      workspaceId: ws,
      deskId: 'demo-desk-garage',
      name: 'P1',
      x: 2,
      y: 2,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
      resourceKind: ResourceKind.parking,
      parkingKind: ParkingKind.standard,
      slotMinutes: 1440,
    ),
    Seat(
      id: DemoResources.slotEv,
      workspaceId: ws,
      deskId: 'demo-desk-garage',
      name: 'P2',
      x: 2 + SeatFootprint.length,
      y: 2,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
      resourceKind: ResourceKind.parking,
      parkingKind: ParkingKind.ev,
      slotMinutes: 1440,
    ),
    Seat(
      id: DemoResources.slotAccessible,
      workspaceId: ws,
      deskId: 'demo-desk-garage',
      name: 'P3',
      x: 2 + 2 * SeatFootprint.length,
      y: 2,
      orientation: SeatOrientation.n,
      chair: '',
      amenities: [],
      resourceKind: ResourceKind.parking,
      parkingKind: ParkingKind.accessible,
      slotMinutes: 1440,
    ),
  ]);
  chargers.stations[DemoResources.slotEv] = const ChargingStation(
    id: 'demo-charger-p2',
    seatId: DemoResources.slotEv,
    name: 'Charger P2',
    connector: ChargerConnector.type2,
    powerKw: 22,
  );
}

void _seedResourceBookings(
  FakeReservationRepository reservations,
  DateTime now,
) {
  const ws = 'ws-1';
  reservations.resourceSeatIds.addAll([
    DemoResources.boardroom,
    DemoResources.slotStandard,
    DemoResources.slotEv,
    DemoResources.slotAccessible,
  ]);
  final today = demoDateOf(now);
  DateTime at(int hour) => demoAt(today.year, today.month, today.day, hour);
  reservations.reservations.addAll([
    // The boardroom from 10:00 to 11:00, while seats are booked by the half
    // day: the two slots live side by side.
    Reservation(
      id: 'demo-boardroom-today',
      workspaceId: ws,
      seatId: DemoResources.boardroom,
      // The member who holds a seat all day holds the room for an hour.
      memberId: 'member-3',
      startsAt: at(10),
      endsAt: at(11),
      status: ReservationStatus.reserved,
    ),
    // The electric slot (and so its charger) for today.
    Reservation(
      id: 'demo-ev-today',
      workspaceId: ws,
      seatId: DemoResources.slotEv,
      memberId: 'member-1',
      startsAt: at(8),
      endsAt: at(18),
      status: ReservationStatus.reserved,
    ),
  ]);
}
