// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 — what the plan and booking features of the reference business show
// instead of being switches that are merely on: three members have a photo
// (the wall tablet's member among them), the ground floor carries a couch and
// a table drawn under its seats, the working day runs nine to six and the
// workspace's booking rules are its own (two places at once, nothing longer
// than ten hours, walk-up only outside the day). The photo is a one-pixel
// picture: the Demo shows faces from a store, and invents none.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/plan/domain/floor_plan.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';

import '../data/floor_plan_repository.dart';
import '../data/profile_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';

final Uint8List _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
);

/// Gives Ada, Bruno and Chiara their photo.
FakeProfileRepository seedDemoPhotos(FakeProfileRepository profiles) {
  for (final person in demoCast.take(3)) {
    final i = profiles.profiles.indexWhere((p) => p.id == person.userId);
    if (i < 0) continue;
    profiles.profiles[i] = profiles.profiles[i].copyWith(
      avatarPath: '${person.userId}/avatar',
    );
    profiles.avatarBytes[person.userId] = _photo;
  }
  return profiles;
}

/// Draws the ground floor's decor and sets the working day and the rules.
void seedDemoPlanAndRules(
  FakeWorkspaceRepository workspaces,
  FakeFloorPlanRepository floorPlan,
) {
  floorPlan.planImages.addAll(const [
    PlanImage(
      id: 'demo-decor-couch',
      levelId: 'level-1',
      rect: GridRect(x: 1, y: 1, w: 6, h: 3),
      kind: PlanDecorKind.couch,
    ),
    PlanImage(
      id: 'demo-decor-table',
      levelId: 'level-1',
      rect: GridRect(x: 9, y: 1, w: 4, h: 3),
      kind: PlanDecorKind.table,
    ),
  ]);
  workspaces
    ..workHours['ws-1'] = const WorkHours(
      startMinutes: 9 * 60,
      halfBoundaryMinutes: 13 * 60,
      endMinutes: 18 * 60,
      halfDayHours: 4,
      fullDayHours: 8,
    )
    ..bookingPolicies['ws-1'] = const BookingPolicies(
      simultaneousReservations: 2,
      maxDurationMinutes: 600,
      outsideHoursMode: OutsideHoursMode.walkupOnly,
    );
}
