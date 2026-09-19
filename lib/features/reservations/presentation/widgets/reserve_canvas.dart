// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/demo/demo_mode.dart';
import '../../../../core/time/clock.dart';
import '../../../members/providers/directory_providers.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/domain/seat.dart';
import '../../../plan/presentation/seat_occupancy.dart';
import '../../../plan/presentation/widgets/plan_canvas.dart';
import '../../../plan/presentation/widgets/seat_photos.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../../profile/domain/profile.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/reservation.dart';
import '../../domain/space_code.dart';
import '../../providers/reservation_providers.dart';
import '../space_subjects.dart';
import 'space_scan.dart';

/// What the Reserve hub is pointing at on the plan (#1301 S1).
typedef ReserveFocus = ({
  String? seatId,
  String? deskId,
  String? officeId,
  bool level,
});

/// #1301 S1 — the Reserve hub's floor plan: the canvas with every overlay
/// the hub draws on it — occupancy, day phases and part-day segments,
/// occupant names and photos, presence dots, whole-space reservations and
/// the whole-space double tap.
///
/// Extracted from `reserve_screen.dart`, which sat at its length cap, with
/// no behaviour change: the screen still owns the date, the window and the
/// focus, and still decides what a seat tap does ([onSeatTap]).
class ReserveCanvas extends ConsumerWidget {
  const ReserveCanvas({
    super.key,
    required this.plan,
    required this.level,
    required this.reservations,
    required this.window,
    required this.dayOpen,
    required this.day,
    required this.focus,
    required this.onSeatTap,
  });

  final FloorPlan plan;
  final Level level;
  final List<Reservation> reservations;

  /// The booking window the hub is showing.
  final HalfDayWindow window;

  /// Whether the workspace is open on the shown day.
  final bool dayOpen;

  /// The whole shown day, for the part-day segments (#903).
  final ({DateTime start, DateTime end}) day;

  final ReserveFocus focus;
  final void Function(Seat seat) onSeatTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final myMemberId = ref.watch(myMemberProvider).value?.id;
    final seatDayOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.seatDayTimeline);
    // #620 — occupant profile photos on every map, kiosk or not.
    final photosOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.planMemberPhotos);
    final memberUserIds = {
      for (final m in ref.watch(workspaceMembersProvider).value ?? <Member>[])
        m.id: m.userId,
    };
    final memberProfiles =
        ref.watch(memberProfilesProvider).value ?? const <String, Profile>{};
    return SeatPhotoLoader(
      seatUserIds: !photosOn
          ? const {}
          : {
              for (final seat in plan.seats)
                if (occupantOnSeat(
                      plan: plan,
                      seat: seat,
                      reservations: reservations,
                      from: window.start,
                      to: window.end,
                    )?.memberId
                    case final occupantMemberId?)
                  if (memberUserIds[occupantMemberId] case final userId?)
                    if (memberProfiles[userId]?.hasAvatar ?? false)
                      seat.id: userId,
            },
      builder: (context, seatPhotos) => PlanCanvas(
        officePalette: ref.watch(workspaceOfficePaletteProvider),
        blurLabels: ref.watch(demoModeControllerProvider).value ?? false,
        seatPhotos: seatPhotos,
        singleRoomByLevel: namesSingleRoomsByLevel(ref),
        paintKey: const ValueKey('reserve-plan-canvas'),
        plan: plan,
        highlightedSeatId: focus.seatId,
        highlightedDeskId: focus.deskId,
        highlightedOfficeId: focus.officeId,
        highlightLevel: focus.level,
        // Double tap = whole-space reserve / check-in (field
        // request); only registered while the feature is on.
        onSpaceDoubleTap:
            ref
                .watch(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.levelBooking)
            ? (desk, office) => showSpaceSheet(
                context,
                // #687 — without this the double-tap sheet
                // offered no subject picker at all, so a whole
                // room or table could only ever be booked for
                // yourself.
                members: spaceAssignmentCandidates(ref),
                kind: desk != null
                    ? SpaceKind.desk
                    : office != null
                    ? SpaceKind.office
                    : SpaceKind.level,
                level: level,
                office:
                    office ??
                    plan.offices
                        .where((o) => o.id == desk?.officeId)
                        .firstOrNull,
                desk: desk,
                plan: plan,
                // Seed the reserve picker with the hub's
                // selected day + period (0065).
                initialWindow: (start: window.start, end: window.end),
              )
            : null,
        // Presence dots: same rule as the directory and Plan tab.
        onlineSeatIds: onlineSeatIdsFor(
          plan: plan,
          reservations: reservations,
          members: ref.watch(workspaceMembersProvider).value ?? const [],
          profiles: ref.watch(memberProfilesProvider).value ?? const {},
          from: window.start,
          to: window.end,
          now: ref.watch(clockProvider).now(),
        ),
        deskOpacity:
            (ref.watch(currentWorkspaceProvider).value?.deskOpacity ?? 100) /
            100,
        background: ref.watch(levelBackgroundProvider(level.id)).value,
        images: {
          for (final image in plan.images)
            // Single watch per image (perf audit): the double watch
            // subscribed twice per image on every rebuild.
            image.id: ?ref.watch(planImageProvider(image.id)).value,
        },
        seatStates: seatStatesFor(
          plan: plan,
          reservations: reservations,
          myMemberId: myMemberId,
          from: window.start,
          to: window.end,
          dayOpen: dayOpen,
        ),
        // #575 — the day-phase rings on the hub's plan too.
        seatDayPhases: seatDayPhasesFor(
          plan: plan,
          reservations: reservations,
          at: window.start,
          dayOpen: dayOpen,
        ),
        // #903 — the day's taken stretches: a seat booked for
        // part of the day is drawn part-filled.
        seatDaySegments: seatDayOn
            ? seatDaySegmentsFor(
                plan: plan,
                reservations: reservations,
                myMemberId: myMemberId,
                dayStart: day.start,
                dayEnd: day.end,
                dayOpen: dayOpen,
              )
            : const {},
        seatLabels: {
          for (final seat in plan.seats)
            seat.id: occupantLabelFor(
              plan: plan,
              seat: seat,
              reservations: reservations,
              names: names,
              from: window.start,
              to: window.end,
            ),
        },
        // #462: the room/table itself reads reserved, with the
        // occupant's name — for every user.
        spaceOverlays: spaceOverlaysFor(
          plan: plan,
          reservations: reservations,
          names: names,
          myMemberId: myMemberId,
          from: window.start,
          to: window.end,
        ),
        onSeatTap: onSeatTap,
      ),
    );
  }
}
