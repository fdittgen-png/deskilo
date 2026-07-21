// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:deskilo/features/plan/domain/desk.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/floor_plan_repository.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/level.dart';
import 'package:deskilo/features/plan/domain/office.dart';
import 'package:deskilo/features/plan/domain/plan_image.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/plan/domain/seat_context.dart';

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
  @override
  Future<void> setLevelBooking(
    String levelId, {
    required bool bookableAsWhole,
    required int priceCents,
  }) async {
    final i = levels.indexWhere((l) => l.id == levelId);
    if (i != -1) {
      levels[i] = levels[i].copyWith(
        bookableAsWhole: bookableAsWhole,
        priceCents: priceCents,
      );
    }
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
  Future<Map<String, String>> fetchTargetNames(String workspaceId) async => {
        for (final s in seats.where((s) => s.workspaceId == workspaceId))
          s.id: s.name,
        for (final o in offices.where((o) => o.workspaceId == workspaceId))
          o.id: o.name,
      };

  @override
  Future<SeatContext?> fetchSeatContext(String seatId) async {
    final seat = seats.where((s) => s.id == seatId).firstOrNull;
    if (seat == null) return null;
    final desk = desks.where((d) => d.id == seat.deskId).firstOrNull;
    if (desk == null) return null;
    final officeContext = await fetchOfficeContext(desk.officeId);
    if (officeContext == null) return null;
    return SeatContext(
      levelId: officeContext.levelId,
      levelName: officeContext.levelName,
      officeName: officeContext.officeName,
      deskName: desk.name,
      seatName: seat.name,
    );
  }

  @override
  Future<SeatContext?> fetchOfficeContext(String officeId) async {
    final office = offices.where((o) => o.id == officeId).firstOrNull;
    if (office == null) return null;
    final level = levels.where((l) => l.id == office.levelId).firstOrNull;
    if (level == null) return null;
    return SeatContext(
      levelId: level.id,
      levelName: level.name,
      officeName: office.name,
    );
  }

  @override
  Future<void> reorderLevels(List<String> orderedLevelIds) async {
    for (var i = 0; i < orderedLevelIds.length; i++) {
      final idx = levels.indexWhere((l) => l.id == orderedLevelIds[i]);
      if (idx >= 0) levels[idx] = levels[idx].copyWith(sortOrder: i);
    }
  }

  /// levelId → background image bytes (0036).
  final backgrounds = <String, Uint8List>{};

  @override
  Future<void> setLevelBackground(
    String workspaceId,
    String levelId, {
    required Uint8List bytes,
    required String contentType,
  }) async {
    backgrounds[levelId] = bytes;
    final idx = levels.indexWhere((l) => l.id == levelId);
    if (idx >= 0) {
      levels[idx] =
          levels[idx].copyWith(backgroundPath: '$workspaceId/$levelId');
    }
  }

  @override
  Future<void> clearLevelBackground(
    String workspaceId,
    String levelId,
  ) async {
    backgrounds.remove(levelId);
    final idx = levels.indexWhere((l) => l.id == levelId);
    if (idx >= 0) {
      levels[idx] = levels[idx].copyWith(backgroundPath: null);
    }
  }

  @override
  Future<Uint8List?> fetchLevelBackground(
    String workspaceId,
    String levelId,
  ) async =>
      backgrounds[levelId];

  /// Illustration images (0037) and their bytes.
  final planImages = <PlanImage>[];
  final imageBytes = <String, Uint8List>{};
  var _imgSeq = 1;

  @override
  Future<PlanImage> createPlanImage({
    required String workspaceId,
    required String levelId,
    required GridRect rect,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final image = PlanImage(
      id: 'img-${_imgSeq++}',
      levelId: levelId,
      rect: rect,
      storagePath: '$workspaceId/img/img-$_imgSeq',
    );
    planImages.add(image);
    imageBytes[image.id] = bytes;
    return image;
  }

  @override
  Future<void> updatePlanImageRect(String imageId, GridRect rect) async {
    final i = planImages.indexWhere((im) => im.id == imageId);
    if (i >= 0) planImages[i] = planImages[i].copyWith(rect: rect);
  }

  @override
  Future<void> deletePlanImage(String imageId) async {
    planImages.removeWhere((im) => im.id == imageId);
    imageBytes.remove(imageId);
  }

  @override
  Future<Uint8List?> fetchPlanImageBytes(String imageId) async =>
      imageBytes[imageId];

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
      images:
          planImages.where((im) => im.levelId == levelId).toList(),
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

  /// Arguments of the last [setSeatBlock] call, for assertions (#161).
  ({String seatId, DateTime? from, DateTime? to})? lastSeatBlock;

  @override
  Future<void> setSeatBlock(
    String seatId, {
    DateTime? from,
    DateTime? to,
  }) async {
    lastSeatBlock = (seatId: seatId, from: from, to: to);
    final i = seats.indexWhere((s) => s.id == seatId);
    if (i < 0) throw StateError('unknown seat $seatId');
    seats[i] = seats[i].copyWith(blockedFrom: from, blockedTo: to);
  }
}
