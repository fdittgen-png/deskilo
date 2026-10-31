// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 — the level canvas's writes, once the member has answered: a
// drag's outcome persisted element by element, the delete that matches
// the selection, a new office, desk, seat or picture, an edited office or
// desk, and the level's background. The screen and its flows ask and
// refresh the plan; this decides which repository call each answer is.
import 'dart:typed_data';

import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/floor_plan_editing.dart';
import '../../plan/domain/floor_plan_repository.dart';
import '../../plan/domain/grid_geometry.dart';
import '../../plan/domain/office.dart';
import '../../plan/domain/seat.dart';

/// A picked image: its bytes and MIME type.
typedef PickedImage = ({Uint8List bytes, String contentType});

class LevelCanvasEdits {
  const LevelCanvasEdits(this._repository, {required this.levelId});

  final FloorPlanRepository _repository;

  /// The level every new element and the background belong to.
  final String levelId;

  Future<void> createOffice(
    String workspaceId, {
    required String name,
    required int color,
    required GridRect rect,
  }) => _repository.createOffice(
    workspaceId: workspaceId,
    levelId: levelId,
    name: name,
    color: color,
    bookableAsWhole: false,
    rect: rect,
  );

  Future<void> createDesk(
    String workspaceId, {
    required String officeId,
    required String name,
    required GridRect rect,
  }) => _repository.createDesk(
    workspaceId: workspaceId,
    officeId: officeId,
    name: name,
    rect: rect,
  );

  /// A plain seat on [deskId] at [anchor].
  Future<void> createSeat(
    String workspaceId, {
    required String deskId,
    required String name,
    required ({int x, int y}) anchor,
    required SeatOrientation orientation,
  }) => _repository.createSeat(
    workspaceId: workspaceId,
    deskId: deskId,
    name: name,
    x: anchor.x,
    y: anchor.y,
    orientation: orientation,
  );

  Future<void> updateOffice(Office office) => _repository.updateOffice(office);

  Future<void> updateDesk(Desk desk) => _repository.updateDesk(desk);

  /// An illustration image at [rect]; [imageId] keeps a retry to one.
  Future<void> createImage(
    String workspaceId, {
    required GridRect rect,
    required PickedImage image,
    required String imageId,
  }) => _repository.createPlanImage(
    workspaceId: workspaceId,
    levelId: levelId,
    rect: rect,
    bytes: image.bytes,
    contentType: image.contentType,
    imageId: imageId,
  );

  /// A drawn symbol at [rect]; [imageId] keeps a retry to one.
  Future<void> createDecor(
    String workspaceId, {
    required PlanDecorKind kind,
    required GridRect rect,
    required String imageId,
  }) => _repository.createPlanDecor(
    workspaceId: workspaceId,
    levelId: levelId,
    rect: rect,
    kind: kind,
    imageId: imageId,
  );

  /// Turns the symbol [image] a quarter clockwise about its centre: the
  /// footprint swaps its sides and the symbol keeps its place, inside the
  /// [cells]-square grid.
  Future<void> rotateDecor(PlanImage image, {required int cells}) async {
    final r = image.rect;
    final cx2 = 2 * r.x + r.w, cy2 = 2 * r.y + r.h;
    // Turned about its centre, and kept on the grid.
    final x = ((cx2 - r.h) / 2).floor().clamp(0, cells - r.h);
    final y = ((cy2 - r.w) / 2).floor().clamp(0, cells - r.w);
    await _repository.updatePlanImageRect(
      image.id,
      GridRect(x: x, y: y, w: r.h, h: r.w),
    );
    await _repository.setPlanDecorTurns(image.id, (image.quarterTurns + 1) % 4);
  }

  /// Removes the symbol created by the last drawing gesture.
  Future<void> undoDecor(String imageId) => _repository.deletePlanImage(imageId);

  Future<void> setBackground(String workspaceId, PickedImage image) =>
      _repository.setLevelBackground(
        workspaceId,
        levelId,
        bytes: image.bytes,
        contentType: image.contentType,
      );

  Future<void> clearBackground(String workspaceId) =>
      _repository.clearLevelBackground(workspaceId, levelId);

  /// Persists every element whose geometry changed between [base] and
  /// [draft] (a moved office drags its desks and seats along).
  Future<void> persistDiff(FloorPlan base, FloorPlan draft) async {
    final baseOffices = {for (final o in base.offices) o.id: o};
    for (final office in draft.offices) {
      if (baseOffices[office.id] != office) {
        await _repository.updateOffice(office);
      }
    }
    final baseDesks = {for (final d in base.desks) d.id: d};
    for (final desk in draft.desks) {
      if (baseDesks[desk.id] != desk) await _repository.updateDesk(desk);
    }
    final baseSeats = {for (final s in base.seats) s.id: s};
    for (final seat in draft.seats) {
      if (baseSeats[seat.id] != seat) await _repository.updateSeat(seat);
    }
    final baseImages = {for (final i in base.images) i.id: i};
    for (final image in draft.images) {
      if (baseImages[image.id] != image) {
        await _repository.updatePlanImageRect(image.id, image.rect);
      }
    }
  }

  /// The delete of the selected element, or null when nothing on [plan]
  /// is selected.
  Future<void> Function()? deleteOf(
    FloorPlan plan,
    ElementKind? kind,
    String? id,
  ) => switch (kind) {
    ElementKind.seat when plan.seats.any((s) => s.id == id) =>
      () => _repository.deleteSeat(id!),
    ElementKind.desk when plan.desks.any((d) => d.id == id) =>
      () => _repository.deleteDesk(id!),
    ElementKind.office when plan.offices.any((o) => o.id == id) =>
      () => _repository.deleteOffice(id!),
    ElementKind.image when plan.images.any((i) => i.id == id) =>
      () => _repository.deletePlanImage(id!),
    _ => null,
  };
}
