// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import 'desk.dart';
import 'office.dart';
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
  }) = _FloorPlan;

  List<Desk> desksOf(String officeId) =>
      desks.where((d) => d.officeId == officeId).toList();

  List<Seat> seatsOf(String deskId) =>
      seats.where((s) => s.deskId == deskId).toList();
}
