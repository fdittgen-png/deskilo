// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic plans and booking history for the London and New York demos.
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../features/plan/domain/desk.dart';
import '../../../features/plan/domain/grid_geometry.dart';
import '../../../features/plan/domain/level.dart';
import '../../../features/plan/domain/office.dart';
import '../../../features/plan/domain/plan_image.dart';
import '../../../features/plan/domain/seat.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/floor_plan_repository.dart';
import '../data/reservation_repository.dart';

/// Four main floors and small, separately identifiable satellite sites.
void seedCityPlans(
  FakeFloorPlanRepository plan, {
  required String workspaceId,
  required String prefix,
  required List<String> sites,
  required List<int> mainFloorOffices,
  bool hourly = false,
}) => _CityPlan(
  plan,
  workspaceId,
  prefix,
  hourly: hourly,
).seed(sites, mainFloorOffices);

class _CityPlan {
  _CityPlan(this.plan, this.workspaceId, this.prefix, {required this.hourly});
  final FakeFloorPlanRepository plan;
  final String workspaceId;
  final String prefix;
  final bool hourly;

  void seed(List<String> sites, List<int> mainFloorOffices) {
    var order = 0;
    for (final (site, siteId) in sites.indexed) {
      final counts = site == 0 ? mainFloorOffices : const [3];
      for (final (floor, count) in counts.indexed) {
        final levelId = '$prefix-level-$site-$floor';
        plan.levels.add(
          Level(
            id: levelId,
            workspaceId: workspaceId,
            siteId: siteId,
            name: site == 0 ? 'Floor ${floor + 1}' : 'Satellite floor',
            sortOrder: order++,
            bookableAsWhole: site > 0,
            priceCents: site > 0 ? 120000 : 0,
          ),
        );
        for (var room = 0; room < count; room++) {
          _office(site, floor, room, levelId);
        }
        if (site == 0 && floor == 0) _parking(levelId);
        if (floor == 0) _utilities(site, levelId);
      }
    }
  }

  void _office(int site, int floor, int room, String levelId) {
    final id = '$prefix-office-$site-$floor-$room';
    final x = (room % 4) * 18, y = (room ~/ 4) * 14;
    plan.offices.add(
      Office(
        id: id,
        workspaceId: workspaceId,
        levelId: levelId,
        name: 'Office ${floor + 1}-${room + 1}',
        color: room % 8,
        bookableAsWhole: true,
        priceCents: 6500,
        rect: GridRect(x: x, y: y, w: 16, h: 12),
      ),
    );
    final deskId = '$id-desk';
    plan.desks.add(
      Desk(
        id: deskId,
        workspaceId: workspaceId,
        officeId: id,
        name: 'Window desk',
        rect: GridRect(x: x + 2, y: y + 2, w: 12, h: 4),
      ),
    );
    for (var seat = 0; seat < 2; seat++) {
      plan.seats.add(
        Seat(
          id: '$deskId-$seat',
          workspaceId: workspaceId,
          deskId: deskId,
          name: '${floor + 1}-${room + 1}-${seat + 1}',
          x: x + 2 + seat * 6,
          y: y + 2,
          orientation: SeatOrientation.n,
          chair: 'ergonomic',
          amenities: const ['monitor', 'dock'],
          slotMinutes: hourly ? 60 : null,
        ),
      );
    }
    plan.planImages.add(
      PlanImage(
        id: '$id-locator',
        levelId: levelId,
        rect: GridRect(x: x + 8, y: y + 7, w: 3, h: 3),
        storagePath: 'demo/office-locator.png',
      ),
    );
    plan.planImages.addAll([
      PlanImage(
        id: '$id-window',
        levelId: levelId,
        rect: GridRect(x: x + 3, y: y, w: 6, h: 1),
        kind: PlanDecorKind.window,
      ),
      PlanImage(
        id: '$id-door',
        levelId: levelId,
        rect: GridRect(x: x + 12, y: y + 9, w: 3, h: 3),
        kind: PlanDecorKind.door,
      ),
      PlanImage(
        id: '$id-landmark',
        levelId: levelId,
        rect: GridRect(x: x + 2, y: y + 8, w: 6, h: 3),
        kind: room.isEven ? PlanDecorKind.couch : PlanDecorKind.table,
      ),
    ]);
  }

  void _parking(String levelId) {
    final id = '$prefix-parking';
    plan.offices.add(
      Office(
        id: id,
        workspaceId: workspaceId,
        levelId: levelId,
        name: 'Parking',
        color: 7,
        areaKind: AreaKind.parking,
        bookableAsWhole: false,
        rect: const GridRect(x: 0, y: 48, w: 32, h: 12),
      ),
    );
    plan.desks.add(
      Desk(
        id: '$id-desk',
        workspaceId: workspaceId,
        officeId: id,
        name: 'Parking bays',
        rect: const GridRect(x: 2, y: 50, w: 24, h: 4),
      ),
    );
    for (var bay = 0; bay < 4; bay++) {
      plan.seats.add(
        Seat(
          id: '$id-$bay',
          workspaceId: workspaceId,
          deskId: '$id-desk',
          name: 'P${bay + 1}',
          x: 2 + bay * 6,
          y: 50,
          orientation: SeatOrientation.n,
          chair: '',
          amenities: const [],
          resourceKind: ResourceKind.parking,
          parkingKind: ParkingKind.standard,
          slotMinutes: hourly ? 60 : null,
        ),
      );
    }
  }

  void _utilities(int site, String levelId) {
    final id = '$prefix-amenities-$site';
    plan.offices.add(
      Office(
        id: id,
        workspaceId: workspaceId,
        levelId: levelId,
        name: 'Vending · colour, B&W, copy and 3D print',
        color: 5,
        bookableAsWhole: false,
        rect: const GridRect(x: 72, y: 0, w: 20, h: 12),
      ),
    );
    plan.planImages.addAll([
      PlanImage(
        id: '$id-vending',
        levelId: levelId,
        rect: const GridRect(x: 74, y: 2, w: 6, h: 3),
        kind: PlanDecorKind.kitchen,
      ),
      PlanImage(
        id: '$id-printer',
        levelId: levelId,
        rect: const GridRect(x: 82, y: 3, w: 8, h: 4),
        kind: PlanDecorKind.table,
      ),
    ]);
  }
}

/// Dense weekday history, deterministic and free of overlapping seat bookings.
typedef CityBookingSpec = ({
  String workspaceId,
  String prefix,
  DateTime now,
  int years,
  List<String> members,
  String timeZone,
  List<({String siteId, String memberId, DateTime month})> siteRentals,
});

void seedCityBookings(
  FakeReservationRepository bookings,
  FakeFloorPlanRepository plan,
  CityBookingSpec spec,
) {
  final (
    :workspaceId,
    :prefix,
    :now,
    :years,
    :members,
    :timeZone,
    :siteRentals,
  ) = spec;
  tzdata.initializeTimeZones();
  final zone = tz.getLocation(timeZone);
  final localNow = tz.TZDateTime.from(now, zone);
  final start = DateTime.utc(
    localNow.year - years,
    localNow.month,
    localNow.day,
  );
  final end = DateTime.utc(
    localNow.year,
    localNow.month,
    localNow.day,
  ).add(const Duration(days: 31));
  final levelByOffice = {
    for (final office in plan.offices) office.id: office.levelId,
  };
  final siteByLevel = {for (final level in plan.levels) level.id: level.siteId};
  final siteByDesk = {
    for (final desk in plan.desks)
      desk.id: siteByLevel[levelByOffice[desk.officeId]],
  };
  for (
    var day = start;
    day.isBefore(end);
    day = day.add(const Duration(days: 1))
  ) {
    if (day.weekday >= DateTime.saturday) continue;
    final ordinal = day.difference(start).inDays;
    for (final (index, seat) in plan.seats.indexed) {
      if (seat.resourceKind != ResourceKind.seat) continue;
      if (_siteRented(siteRentals, siteByDesk[seat.deskId], day)) {
        continue;
      }
      if ((ordinal + index) % 11 == 0) continue;
      final begins = tz.TZDateTime(
        zone,
        day.year,
        day.month,
        day.day,
        9,
      ).toUtc();
      final ends = begins.add(const Duration(hours: 8));
      final past = !ends.isAfter(now);
      bookings.reservations.add(
        Reservation(
          id: '$prefix-book-$ordinal-$index',
          workspaceId: workspaceId,
          seatId: seat.id,
          memberId: members[(ordinal + index) % members.length],
          startsAt: begins,
          endsAt: ends,
          status: past
              ? ReservationStatus.completed
              : ReservationStatus.reserved,
          checkedInAt: past ? begins : null,
          checkedOutAt: past ? ends : null,
        ),
      );
    }
  }
  for (final (index, rental) in siteRentals.indexed) {
    final from = tz.TZDateTime(
      zone,
      rental.month.year,
      rental.month.month,
    ).toUtc();
    final to = tz.TZDateTime(
      zone,
      rental.month.year,
      rental.month.month + 1,
    ).toUtc();
    for (final level in plan.levels.where((l) => l.siteId == rental.siteId)) {
      bookings.reservations.add(
        Reservation(
          id: '$prefix-site-rental-$index-${level.id}',
          workspaceId: workspaceId,
          levelId: level.id,
          memberId: rental.memberId,
          startsAt: from,
          endsAt: to,
          status: ReservationStatus.completed,
        ),
      );
    }
  }
}

bool _siteRented(
  List<({String siteId, String memberId, DateTime month})> rentals,
  String? site,
  DateTime day,
) => rentals.any(
  (r) =>
      r.siteId == site &&
      r.month.year == day.year &&
      r.month.month == day.month,
);
