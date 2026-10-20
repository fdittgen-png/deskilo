// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/room_level_kind.dart';
import '../../../features/money/domain/room_rental.dart';

/// #2568 — the rented rooms in memory, with the server's rules the screen
/// shows: a rental sits on a room of an external level, ends no earlier than
/// it starts, and a level with a rental stays external.
class FakeRoomRentalRepository implements RoomRentalRepository {
  FakeRoomRentalRepository({
    Iterable<RoomLevel> levels = const [],
    Iterable<RentableRoom> rooms = const [],
    Iterable<RoomRental> rentals = const [],
    this.supplierName = 'Landlord',
    Iterable<RoomPlan> plans = const [],
  }) : plans = [...plans],
       levels = [...levels],
       rooms = [...rooms],
       rentals = [...rentals];

  final List<RoomLevel> levels;
  final List<RentableRoom> rooms;
  final List<RoomRental> rentals;
  final List<RoomPlan> plans;
  final String supplierName;

  @override
  Future<List<RoomPlan>> fetchPlans(String workspaceId) async => [...plans];

  @override
  Future<RoomRentalsOverview> fetchOverview(String workspaceId) async =>
      RoomRentalsOverview(
        rentals: [...rentals],
        levels: [...levels],
        rooms: [
          for (final r in rooms)
            RentableRoom(
              officeId: r.officeId,
              name: r.name,
              levelName: r.levelName,
              rented: rentals.any((x) => x.officeId == r.officeId),
            ),
        ],
      );

  @override
  Future<void> setLevelKind(
    String workspaceId,
    String levelId,
    LevelKind kind,
  ) async {
    final i = levels.indexWhere((l) => l.id == levelId);
    if (i < 0) throw StateError('unknown level');
    final level = levels[i];
    if (kind == LevelKind.own &&
        rentals.any(
          (r) => rooms.any(
            (x) => x.officeId == r.officeId && x.levelName == level.name,
          ),
        )) {
      throw StateError('end the rentals of this level first');
    }
    levels[i] = RoomLevel(id: level.id, name: level.name, kind: kind);
  }

  @override
  Future<RoomRental> saveRental(
    String workspaceId,
    RoomRentalCommand command,
  ) async {
    final until = command.availableUntil;
    if (until != null && until.isBefore(command.availableFrom)) {
      throw StateError('the rental cannot end before it starts');
    }
    final room = rooms.where((r) => r.officeId == command.officeId).firstOrNull;
    if (room == null) {
      throw StateError('a rented room sits on an external level');
    }
    final i = rentals.indexWhere((r) => r.officeId == command.officeId);
    if (i >= 0 && rentals[i].revision != command.revision) {
      throw StateError('the rental changed meanwhile');
    }
    final next = RoomRental(
      id: i >= 0 ? rentals[i].id : 'demo-rental-${rentals.length + 1}',
      revision: i >= 0 ? rentals[i].revision + 1 : 1,
      officeId: command.officeId,
      officeName: room.name,
      supplierId: command.supplierId,
      supplierName: supplierName,
      availableFrom: command.availableFrom,
      availableUntil: command.availableUntil,
      status: command.status,
      costKind: command.costKind,
      costCents: command.costCents,
      period: command.period,
      currency: 'EUR',
      audienceAll: command.audienceAll,
      audience: command.audience,
      fees: command.fees,
    );
    if (i >= 0) {
      rentals[i] = next;
    } else {
      rentals.add(next);
    }
    return next;
  }

  @override
  Future<RoomOffer> fetchOffer(String workspaceId, String officeId) async {
    final r = rentals.where((x) => x.officeId == officeId).firstOrNull;
    if (r == null || r.status != RoomRentalStatus.active) {
      throw StateError('that room is not open to you');
    }
    return RoomOffer(
      officeId: officeId,
      availableFrom: r.availableFrom,
      availableUntil: r.availableUntil,
      currency: r.currency,
      fees: [
        for (final f in r.fees)
          if (f.audience.memberId == null &&
              f.audience.planId == null &&
              f.audience.roleId == null)
            f,
      ],
    );
  }
}
