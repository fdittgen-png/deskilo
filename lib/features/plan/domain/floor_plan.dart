// SPDX-License-Identifier: MIT
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
}
