// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import 'desk.dart';
import 'office.dart';
import 'plan_image.dart';
import 'seat.dart';

part 'floor_plan.freezed.dart';

/// Everything drawn on one level.
@freezed
sealed class FloorPlan with _$FloorPlan {
  const FloorPlan._();

  const factory FloorPlan({
    required String levelId,
    required List<Office> offices,
    required List<Desk> desks,
    required List<Seat> seats,
    @Default(<PlanImage>[]) List<PlanImage> images,
  }) = _FloorPlan;

  List<Desk> desksOf(String officeId) =>
      desks.where((d) => d.officeId == officeId).toList();

  List<Seat> seatsOf(String deskId) =>
      seats.where((s) => s.deskId == deskId).toList();

  Office? officeAtCell(int x, int y) =>
      offices.where((o) => o.rect.containsCell(x, y)).firstOrNull;

  Desk? deskAtCell(int x, int y) =>
      desks.where((d) => d.rect.containsCell(x, y)).firstOrNull;

  Seat? seatAtCell(int x, int y) =>
      seats.where((s) => s.footprint.containsCell(x, y)).firstOrNull;

  /// The topmost illustration image covering (x, y), if any (0037).
  PlanImage? imageAtCell(int x, int y) =>
      images.where((i) => i.rect.containsCell(x, y)).lastOrNull;

  /// Bounding box (in grid cells) of everything drawn on the level — rooms,
  /// desks, seats and illustration images. Null when the level is empty.
  /// Used to auto-fit the plan to the screen ("size the office to view").
  ({int x, int y, int w, int h})? get usedBounds {
    int? minX, minY, maxX, maxY;
    void add(int x, int y, int w, int h) {
      minX = minX == null ? x : (x < minX! ? x : minX);
      minY = minY == null ? y : (y < minY! ? y : minY);
      maxX = maxX == null ? x + w : (x + w > maxX! ? x + w : maxX);
      maxY = maxY == null ? y + h : (y + h > maxY! ? y + h : maxY);
    }

    for (final o in offices) {
      add(o.rect.x, o.rect.y, o.rect.w, o.rect.h);
    }
    for (final i in images) {
      add(i.rect.x, i.rect.y, i.rect.w, i.rect.h);
    }
    for (final s in seats) {
      add(s.footprint.x, s.footprint.y, s.footprint.w, s.footprint.h);
    }
    if (minX == null) return null;
    return (x: minX!, y: minY!, w: maxX! - minX!, h: maxY! - minY!);
  }
}
