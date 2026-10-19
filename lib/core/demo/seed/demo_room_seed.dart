// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2568 — the demo space's rented rooms: a floor in the building next door,
// one room rented from the landlord for the year and open to every member at
// 15.00 a half day, and a second room nobody has rented yet.
import '../../../features/money/domain/room_level_kind.dart';
import '../../../features/money/domain/room_rental.dart';
import '../data/room_rental_repository.dart';

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
