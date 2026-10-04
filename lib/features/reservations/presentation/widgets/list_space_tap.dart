// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/domain/level.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/space_code.dart';
import '../space_subjects.dart';
import 'space_scan.dart';

/// #1825 — the reserve list's header action: the whole office or desk,
/// through the same sheet the canvas double-tap opens. Null when this
/// member may not reserve a space as a whole: the feature, an active
/// membership, and the grant, the admin role or an assignment roster
/// (space_scan's rule). Called with neither a desk nor an office, it
/// opens the whole LEVEL — offered only where [levelReservable] says so.
void Function(String? deskId, String? officeId)? listSpaceTap(
  BuildContext context,
  WidgetRef ref, {
  required Level level,
  required FloorPlan plan,
  required HalfDayWindow window,
}) {
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.levelBooking)) {
    return null;
  }
  final me = ref.watch(myMemberProvider).value;
  if (me == null || me.status != MemberStatus.active) return null;
  final roster = spaceAssignmentCandidates(ref);
  if (!me.canReserveLevel && !ref.watch(actsForReservationsProvider) && roster.isEmpty) return null;
  return (deskId, officeId) {
    final desk = plan.desks.where((d) => d.id == deskId).firstOrNull;
    showSpaceSheet(
      context,
      members: roster,
      kind: desk != null
          ? SpaceKind.desk
          : officeId != null
              ? SpaceKind.office
              : SpaceKind.level,
      level: level,
      office: plan.offices
          .where((o) => o.id == (officeId ?? desk?.officeId))
          .firstOrNull,
      desk: desk,
      plan: plan,
      initialWindow: (start: window.start, end: window.end),
    );
  };
}

/// #1825 — whether [level] offers its whole-level reservation to me: the
/// level rail's stricter #466 rule (feature on, level bookable as a
/// whole, and the grant or the admin role; a roster alone is not enough).
bool levelReservable(WidgetRef ref, Level? level) {
  if (level == null || !level.bookableAsWhole) return false;
  if (!ref
      .watch(enabledFeaturesSyncProvider)
      .contains(WorkspaceFeature.levelBooking)) {
    return false;
  }
  final me = ref.watch(myMemberProvider).value;
  if (me == null || me.status != MemberStatus.active) return false;
  return me.canReserveLevel || ref.watch(actsForReservationsProvider);
}
