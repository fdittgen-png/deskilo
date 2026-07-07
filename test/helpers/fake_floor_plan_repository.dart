// SPDX-License-Identifier: MIT
import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/seat.dart';

/// In-memory [FloorPlanRepository] (fakes over mocks).
class FakeFloorPlanRepository implements FloorPlanRepository {
  final levels = <Level>[];
  final offices = <Office>[];
  final desks = <Desk>[];
  final seats = <Seat>[];
  var _nextId = 1;

  String _id(String prefix) => '$prefix-${_nextId++}';

  /// Seeds one level with one office, one desk and one seat.
  void seedSmallPlan({String workspaceId = 'ws-1'}) {
    final level = Level(
      id: _id('level'),
      workspaceId: workspaceId,
      name: 'Ground floor',
      sortOrder: 0,
    );
    levels.add(level);
    final office = Office(
      id: _id('office'),
      workspaceId: workspaceId,
      levelId: level.id,
      name: 'Main room',
      color: 0,
      bookableAsWhole: false,
      rect: const GridRect(x: 0, y: 0, w: 30, h: 20),
    );
    offices.add(office);
    final desk = Desk(
      id: _id('desk'),
      workspaceId: workspaceId,
      officeId: office.id,
      name: 'Window desk',
      rect: const GridRect(x: 2, y: 2, w: 12, h: 4),
    );
    desks.add(desk);
    seats.add(
      Seat(
        id: _id('seat'),
        workspaceId: workspaceId,
        deskId: desk.id,
        name: 'A1',
        x: 2,
        y: 2,
        orientation: SeatOrientation.n,
        chair: 'standard',
        amenities: const ['monitor'],
      ),
    );
  }

  @override
  Future<List<Level>> fetchLevels(String workspaceId) async =>
      levels.where((l) => l.workspaceId == workspaceId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  @override
  Future<Level> createLevel(
    String workspaceId,
    String name,
    int sortOrder,
  ) async {
    final level = Level(
      id: _id('level'),
      workspaceId: workspaceId,
      name: name,
      sortOrder: sortOrder,
    );
    levels.add(level);
    return level;
  }

  @override
  Future<void> renameLevel(String levelId, String name) async {
    final i = levels.indexWhere((l) => l.id == levelId);
    if (i >= 0) levels[i] = levels[i].copyWith(name: name);
  }

  @override
  Future<void> deleteLevel(String levelId) async {
    levels.removeWhere((l) => l.id == levelId);
    final officeIds =
        offices.where((o) => o.levelId == levelId).map((o) => o.id).toSet();
    offices.removeWhere((o) => o.levelId == levelId);
    final deskIds = desks
        .where((d) => officeIds.contains(d.officeId))
        .map((d) => d.id)
        .toSet();
    desks.removeWhere((d) => officeIds.contains(d.officeId));
    seats.removeWhere((s) => deskIds.contains(s.deskId));
  }

  @override
  Future<FloorPlan> fetchPlan(String levelId) async {
    final levelOffices = offices.where((o) => o.levelId == levelId).toList();
    final officeIds = levelOffices.map((o) => o.id).toSet();
    final levelDesks =
        desks.where((d) => officeIds.contains(d.officeId)).toList();
    final deskIds = levelDesks.map((d) => d.id).toSet();
    return FloorPlan(
      levelId: levelId,
      offices: levelOffices,
      desks: levelDesks,
      seats: seats.where((s) => deskIds.contains(s.deskId)).toList(),
    );
  }

  @override
  Future<Office> createOffice({
    required String workspaceId,
    required String levelId,
    required String name,
    required int color,
    required bool bookableAsWhole,
    required GridRect rect,
  }) async {
    final office = Office(
      id: _id('office'),
      workspaceId: workspaceId,
      levelId: levelId,
      name: name,
      color: color,
      bookableAsWhole: bookableAsWhole,
      rect: rect,
    );
    offices.add(office);
    return office;
  }

  @override
  Future<void> updateOffice(Office office) async {
    final i = offices.indexWhere((o) => o.id == office.id);
    if (i >= 0) offices[i] = office;
  }

  @override
  Future<void> deleteOffice(String officeId) async {
    offices.removeWhere((o) => o.id == officeId);
    final deskIds =
        desks.where((d) => d.officeId == officeId).map((d) => d.id).toSet();
    desks.removeWhere((d) => d.officeId == officeId);
    seats.removeWhere((s) => deskIds.contains(s.deskId));
  }

  @override
  Future<Desk> createDesk({
    required String workspaceId,
    required String officeId,
    required String name,
    required GridRect rect,
  }) async {
    final desk = Desk(
      id: _id('desk'),
      workspaceId: workspaceId,
      officeId: officeId,
      name: name,
      rect: rect,
    );
    desks.add(desk);
    return desk;
  }

  @override
  Future<void> updateDesk(Desk desk) async {
    final i = desks.indexWhere((d) => d.id == desk.id);
    if (i >= 0) desks[i] = desk;
  }

  @override
  Future<void> deleteDesk(String deskId) async {
    desks.removeWhere((d) => d.id == deskId);
    seats.removeWhere((s) => s.deskId == deskId);
  }

  @override
  Future<Seat> createSeat({
    required String workspaceId,
    required String deskId,
    required String name,
    required int x,
    required int y,
    required SeatOrientation orientation,
  }) async {
    final seat = Seat(
      id: _id('seat'),
      workspaceId: workspaceId,
      deskId: deskId,
      name: name,
      x: x,
      y: y,
      orientation: orientation,
      chair: '',
      amenities: const [],
    );
    seats.add(seat);
    return seat;
  }

  @override
  Future<void> updateSeat(Seat seat) async {
    final i = seats.indexWhere((s) => s.id == seat.id);
    if (i >= 0) seats[i] = seat;
  }

  @override
  Future<void> deleteSeat(String seatId) async {
    seats.removeWhere((s) => s.id == seatId);
  }
}
