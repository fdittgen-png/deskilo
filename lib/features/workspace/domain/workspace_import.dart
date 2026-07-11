// SPDX-License-Identifier: MIT
import '../../plan/domain/desk.dart';
import '../../plan/domain/floor_plan_rules.dart';
import '../../plan/domain/office.dart';
import '../../plan/domain/seat.dart';
import 'workspace_xml.dart';

/// The exact message the `import_floor_plan` RPC (migration 0023) raises
/// when the workspace already has reservation rows. Reservations reference
/// seats (0005, on delete RESTRICT) and billing counts them, so v1 only
/// imports into reservation-free workspaces. The UI maps this to its own
/// localized explanation instead of the generic error.
const String kWorkspaceHasReservationsError = 'workspace has reservations';

/// jsonb keys of the `import_floor_plan` payload (migration 0023). The
/// shape mirrors the XML schema (#164): an array of levels, each nesting
/// offices[desks[seats[amenities]]] — no ids, import regenerates them.
abstract final class WorkspaceImportPlanKeys {
  static const String name = 'name';
  static const String sortOrder = 'sort_order';
  static const String offices = 'offices';
  static const String color = 'color';
  static const String bookableAsWhole = 'bookable_as_whole';
  static const String x = 'x';
  static const String y = 'y';
  static const String w = 'w';
  static const String h = 'h';
  static const String desks = 'desks';
  static const String seats = 'seats';
  static const String orientation = 'orientation';
  static const String chair = 'chair';
  static const String amenities = 'amenities';
  static const String blockedFrom = 'blocked_from';
  static const String blockedTo = 'blocked_to';
}

/// Owner-only import boundary (#165). Separate from [WorkspaceRepository]
/// so the shared test fake keeps compiling untouched; Supabase impl in
/// data/, fakes in the import tests.
abstract class WorkspaceImportRepository {
  /// Transactionally replaces the workspace's floor plan with the parsed
  /// file's levels via the `import_floor_plan` RPC. Throws the backend's
  /// [kWorkspaceHasReservationsError] when any reservation exists.
  Future<void> importFloorPlan(String workspaceId, WorkspaceXmlData data);
}

/// Converts the parsed floor plan to the `import_floor_plan` jsonb
/// payload. Pure so unit tests can round-trip it against the codec.
List<Map<String, Object?>> workspaceXmlPlanToJson(
  List<WorkspaceXmlLevel> levels,
) {
  return [
    for (final level in levels)
      {
        WorkspaceImportPlanKeys.name: level.name,
        WorkspaceImportPlanKeys.sortOrder: level.sortOrder,
        WorkspaceImportPlanKeys.offices: [
          for (final office in level.offices)
            {
              WorkspaceImportPlanKeys.name: office.name,
              WorkspaceImportPlanKeys.color: office.color,
              WorkspaceImportPlanKeys.bookableAsWhole: office.bookableAsWhole,
              WorkspaceImportPlanKeys.x: office.rect.x,
              WorkspaceImportPlanKeys.y: office.rect.y,
              WorkspaceImportPlanKeys.w: office.rect.w,
              WorkspaceImportPlanKeys.h: office.rect.h,
              WorkspaceImportPlanKeys.desks: [
                for (final desk in office.desks)
                  {
                    WorkspaceImportPlanKeys.name: desk.name,
                    WorkspaceImportPlanKeys.x: desk.rect.x,
                    WorkspaceImportPlanKeys.y: desk.rect.y,
                    WorkspaceImportPlanKeys.w: desk.rect.w,
                    WorkspaceImportPlanKeys.h: desk.rect.h,
                    WorkspaceImportPlanKeys.seats: [
                      for (final seat in desk.seats)
                        {
                          WorkspaceImportPlanKeys.name: seat.name,
                          WorkspaceImportPlanKeys.x: seat.x,
                          WorkspaceImportPlanKeys.y: seat.y,
                          WorkspaceImportPlanKeys.orientation:
                              seat.orientation.name,
                          WorkspaceImportPlanKeys.chair: seat.chair,
                          WorkspaceImportPlanKeys.amenities: seat.amenities,
                          WorkspaceImportPlanKeys.blockedFrom: seat.blockedFrom
                              ?.toUtc()
                              .toIso8601String(),
                          WorkspaceImportPlanKeys.blockedTo:
                              seat.blockedTo?.toUtc().toIso8601String(),
                        },
                    ],
                  },
              ],
            },
        ],
      },
  ];
}

/// Simple counts for the confirm-dialog summary ("2 levels, 3 offices,
/// 8 desks, 14 seats").
({int levels, int offices, int desks, int seats}) workspaceXmlPlanCounts(
  WorkspaceXmlData data,
) {
  var offices = 0;
  var desks = 0;
  var seats = 0;
  for (final level in data.levels) {
    offices += level.offices.length;
    for (final office in level.offices) {
      desks += office.desks.length;
      for (final desk in office.desks) {
        seats += desk.seats.length;
      }
    }
  }
  return (
    levels: data.levels.length,
    offices: offices,
    desks: desks,
    seats: seats,
  );
}

/// Runs the editor's placement rules (spec §10, floor_plan_rules.dart)
/// over a parsed file BEFORE the preview: overlapping offices/desks/seats
/// and out-of-parent geometry are rejected client-side with one localized
/// message; [detail] names the offending item for the trace log only.
///
/// The parsed structure carries no ids, so short synthetic ones are minted
/// purely to satisfy the rule functions' `ignoreId`/sibling checks.
({PlacementProblem problem, String detail})? validateWorkspaceXmlPlan(
  WorkspaceXmlData data,
) {
  for (final (levelIndex, level) in data.levels.indexed) {
    final placedOffices = <Office>[];
    final placedLevelDesks = <Desk>[];
    for (final (officeIndex, office) in level.offices.indexed) {
      final officeProblem = validateOfficePlacement(office.rect, placedOffices);
      if (officeProblem != null) {
        return (
          problem: officeProblem,
          detail: 'office "${office.name}" on level "${level.name}"',
        );
      }
      final officeModel = Office(
        id: 'l$levelIndex-o$officeIndex',
        workspaceId: '',
        levelId: 'l$levelIndex',
        name: office.name,
        color: office.color,
        bookableAsWhole: office.bookableAsWhole,
        rect: office.rect,
      );
      placedOffices.add(officeModel);
      for (final (deskIndex, desk) in office.desks.indexed) {
        // Desks are checked against ALL desks placed on the level so far —
        // the same sibling scope the editor uses (floor_plan_rules.dart).
        final deskProblem =
            validateDeskPlacement(desk.rect, officeModel, placedLevelDesks);
        if (deskProblem != null) {
          return (
            problem: deskProblem,
            detail: 'desk "${desk.name}" in office "${office.name}"',
          );
        }
        final deskModel = Desk(
          id: '${officeModel.id}-d$deskIndex',
          workspaceId: '',
          officeId: officeModel.id,
          name: desk.name,
          rect: desk.rect,
        );
        placedLevelDesks.add(deskModel);
        final placedSeats = <Seat>[];
        for (final (seatIndex, seat) in desk.seats.indexed) {
          final seatModel = Seat(
            id: '${deskModel.id}-s$seatIndex',
            workspaceId: '',
            deskId: deskModel.id,
            name: seat.name,
            x: seat.x,
            y: seat.y,
            orientation: seat.orientation,
            chair: seat.chair,
            amenities: seat.amenities,
            blockedFrom: seat.blockedFrom,
            blockedTo: seat.blockedTo,
          );
          final seatProblem =
              validateSeatPlacement(seatModel, deskModel, placedSeats);
          if (seatProblem != null) {
            return (
              problem: seatProblem,
              detail: 'seat "${seat.name}" on desk "${desk.name}"',
            );
          }
          placedSeats.add(seatModel);
        }
      }
    }
  }
  return null;
}
