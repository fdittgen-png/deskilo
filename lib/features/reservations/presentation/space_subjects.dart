// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/reservation_providers.dart';

/// Who a WHOLE SPACE may be reserved for (#687), in one place.
///
/// Every surface that can open the whole-space sheet has to answer this
/// the same way: the plan's double-tap, the level button, a scanned
/// space code and a `[space:…]` reference in a message all reserve the
/// same room. Four copies of the rule is four chances for one of them to
/// quietly offer no picker — which is exactly what three of them did
/// before this existed, so an admin could assign a floor by double-
/// tapping it and not by scanning the card stuck to its door.
///
/// The gate is 0079/#638 and is deliberately NOT the seat rule (#106):
/// handing out a whole floor is a bigger act than handing out a desk,
/// and a workspace delegates the two separately.
List<({String id, String name})> spaceAssignmentCandidates(WidgetRef ref) {
  final me = ref.read(myMemberProvider).value;
  if (me == null) return const [];
  final features = ref.read(enabledFeaturesSyncProvider);
  final allowed = me.actsAsOwner ||
      (me.canAdminister &&
          features.contains(WorkspaceFeature.adminLevelAssign));
  if (!allowed) return const [];
  final names = ref.read(memberNamesProvider).value ?? const {};
  return [
    // Kiosk members are excluded: a kiosk is a shared tablet, not a
    // person, and assigning it a room creates a booking nobody holds.
    for (final m in (ref.read(workspaceMembersProvider).value ?? const <Member>[])
        .where((m) => m.status == MemberStatus.active && !m.isKiosk))
      (id: m.id, name: names[m.id] ?? ''),
  ];
}
