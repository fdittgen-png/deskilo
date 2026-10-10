// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the demo space as a place worth documenting: two floors, a
// meeting room booked as a whole, a team desk, seat accessories, closure
// days around the demo's "today". Every date follows the session's
// seeded instant, never a literal.
import '../../../features/plan/domain/desk.dart';
import '../../../features/plan/domain/grid_geometry.dart';
import '../../../features/plan/domain/level.dart';
import '../../../features/plan/domain/office.dart';
import '../../../features/plan/domain/seat.dart';
import '../../../features/workspace/domain/closure_day.dart';
import '../data/accessory_repository.dart';
import '../data/floor_plan_repository.dart';
import '../data/workspace_repository.dart';

/// Ids the bookings and the guides tell stories about.
abstract final class DemoSpace {
  static const firstFloor = 'demo-level-first';
  static const meetingRoom = 'demo-office-meeting';
  static const studio = 'demo-office-studio';
  static const teamDesk = 'demo-desk-team';
  static const studioSeats = ['demo-seat-s1', 'demo-seat-s2'];
}

/// A second floor: a meeting room booked as a whole (with its price) and
/// a studio whose team desk can be booked as a whole too.
void seedDemoSpace(FakeFloorPlanRepository plan) {
  const ws = 'ws-1';
  plan.levels.add(
    const Level(
      id: DemoSpace.firstFloor,
      workspaceId: ws,
      name: 'First floor',
      sortOrder: 1,
      bookableAsWhole: true,
      priceCents: 24000,
    ),
  );
  plan.offices.addAll(const [
    Office(
      id: DemoSpace.meetingRoom,
      workspaceId: ws,
      levelId: DemoSpace.firstFloor,
      name: 'Meeting room',
      color: 2,
      bookableAsWhole: true,
      priceCents: 4000,
      rect: GridRect(x: 0, y: 0, w: 14, h: 10),
    ),
    Office(
      id: DemoSpace.studio,
      workspaceId: ws,
      levelId: DemoSpace.firstFloor,
      name: 'Studio',
      color: 4,
      bookableAsWhole: false,
      rect: GridRect(x: 16, y: 0, w: 14, h: 10),
    ),
  ]);
  plan.desks.add(
    const Desk(
      id: DemoSpace.teamDesk,
      workspaceId: ws,
      officeId: DemoSpace.studio,
      name: 'Team desk',
      bookableAsWhole: true,
      priceCents: 3000,
      // #2327 — two whole seat footprints (6 cells each), side by side.
      rect: GridRect(x: 18, y: 2, w: 2 * SeatFootprint.length, h: 4),
    ),
  );
  for (final (i, id) in DemoSpace.studioSeats.indexed) {
    plan.seats.add(
      Seat(
        id: id,
        workspaceId: ws,
        deskId: DemoSpace.teamDesk,
        name: 'S${i + 1}',
        x: 18 + i * SeatFootprint.length,
        y: 2,
        orientation: SeatOrientation.n,
        chair: 'ergonomic',
        amenities: const ['monitor', 'dock'],
      ),
    );
  }
}

/// The accessory catalogue and which seats carry what.
void seedDemoAccessories(
  FakeAccessoryRepository accessories,
  FakeFloorPlanRepository plan,
) {
  accessories.seedSmallCatalog();
  final monitor = accessories.accessories.first.id;
  final standing = accessories.accessories[1].id;
  accessories.seatAccessories
    ..[plan.seats.first.id] = {monitor}
    ..[DemoSpace.studioSeats.first] = {monitor, standing};
}

/// Two closure days ahead of "today" — a bank holiday and an
/// inventory day — so the calendar and the booking sheet refuse them.
void seedDemoClosures(FakeWorkspaceRepository workspaces, DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  workspaces.closureDays.addAll([
    ClosureDay(
      id: 'demo-closure-holiday',
      workspaceId: 'ws-1',
      day: day.add(const Duration(days: 15)),
      reason: 'Public holiday',
    ),
    ClosureDay(
      id: 'demo-closure-inventory',
      workspaceId: 'ws-1',
      day: day.add(const Duration(days: 23)),
      reason: 'Inventory',
    ),
  ]);
}
