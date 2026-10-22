// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2568 — the demo space's rented rooms: a floor in the building next door,
// one room rented from the landlord for the year and open to every member at
// 15.00 a half day, and a second room nobody has rented yet.
import '../../../features/money/domain/room_level_kind.dart';
import '../../../features/money/domain/room_rental.dart';
import '../../../features/plan/domain/grid_geometry.dart';
import '../../../features/plan/domain/level.dart';
import '../../../features/plan/domain/office.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/floor_plan_repository.dart';
import '../data/reservation_repository.dart';
import '../data/room_rental_repository.dart';
import '../demo_clock.dart';

FakeRoomRentalRepository seedDemoRooms(DateTime now) =>
    FakeRoomRentalRepository(
      supplierName: 'Immobilière du Midi',
      levels: const [
        RoomLevel(
          id: 'demo-level-own',
          name: 'Ground floor',
          kind: LevelKind.own,
        ),
        RoomLevel(
          id: 'demo-level-annex',
          name: 'Annex, 1st floor',
          kind: LevelKind.external,
        ),
      ],
      rooms: const [
        RentableRoom(
          officeId: 'demo-room-studio',
          name: 'Studio',
          levelName: 'Annex, 1st floor',
          rented: true,
        ),
        RentableRoom(
          officeId: 'demo-room-loft',
          name: 'Loft',
          levelName: 'Annex, 1st floor',
          rented: false,
        ),
      ],
      rentals: [
        RoomRental(
          id: 'demo-rental-studio',
          revision: 2,
          officeId: 'demo-room-studio',
          officeName: 'Studio',
          supplierId: 'demo-supplier-immo',
          supplierName: 'Immobilière du Midi',
          availableFrom: DateTime(now.year),
          availableUntil: DateTime(now.year, 12, 31),
          status: RoomRentalStatus.active,
          costCents: 40000,
          currency: 'EUR',
          audienceAll: true,
          fees: const [RoomFee(unit: RoomFeeUnit.halfDay, feeCents: 1500)],
        ),
      ],
    );

/// The annex on the floor plan: the level next door and its two rooms, the
/// rented Studio bookable as a whole, and Ada's half-day in it the day
/// after tomorrow — what renting a room is for.
void seedDemoAnnex(
  FakeFloorPlanRepository plan,
  FakeReservationRepository reservations,
  DateTime now,
) {
  const ws = 'ws-1';
  plan.levels.add(
    const Level(
      id: 'demo-level-annex',
      workspaceId: ws,
      name: 'Annex, 1st floor',
      sortOrder: 3,
    ),
  );
  plan.offices.addAll(const [
    Office(
      id: 'demo-room-studio',
      workspaceId: ws,
      levelId: 'demo-level-annex',
      name: 'Studio',
      color: 6,
      bookableAsWhole: true,
      priceCents: 1500,
      rect: GridRect(x: 0, y: 0, w: 14, h: 10),
    ),
    Office(
      id: 'demo-room-loft',
      workspaceId: ws,
      levelId: 'demo-level-annex',
      name: 'Loft',
      color: 7,
      bookableAsWhole: false,
      rect: GridRect(x: 16, y: 0, w: 14, h: 10),
    ),
  ]);
  final day = demoDateOf(now);
  reservations.reservations.add(
    Reservation(
      id: 'demo-annex-studio',
      workspaceId: ws,
      officeId: 'demo-room-studio',
      memberId: 'member-1',
      startsAt: demoAt(day.year, day.month, day.day + 2, 9),
      endsAt: demoAt(day.year, day.month, day.day + 2, 13),
      status: ReservationStatus.reserved,
    ),
  );
}
