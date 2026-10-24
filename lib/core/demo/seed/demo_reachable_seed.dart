// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 — who the demo's persona can write to, as my_reachable_people
// answers it: the active people of both demo spaces (the cast, nobody
// new), one row per person per space, the persona left out. Ada and
// Bruno work in both spaces, so they are listed under both. A pending or
// paused membership is not reachable (0547 lists active members only).
//
// And the one group of people the cast keeps, so the new-discussion
// directory and its suggestions have a group to show.
import 'package:meta/meta.dart';

import '../../../features/directory/domain/account_group.dart';
import '../../../features/directory/domain/messenger.dart';
import '../../../features/directory/domain/public_workspace.dart';
import '../../../features/workspace/domain/member.dart';
import '../data/messenger_repository.dart';
import '../demo_dataset.dart';
import 'demo_people_seed.dart';
import 'demo_second_space_seed.dart';

/// The people [actingMember] can write to, by shared space.
List<ReachablePerson> demoReachablePeople(String actingMember) {
  final spaces = [
    ('ws-1', demoSpaceName, demoCast),
    (demoSecondSpaceId, demoSecondSpaceName, demoSecondCast),
  ];
  final mine = {
    for (final (id, _, cast) in spaces)
      if (cast.any((p) => p.memberId == actingMember)) id,
  };
  return [
    for (final (id, name, cast) in spaces)
      if (mine.contains(id))
        for (final p in cast)
          if (p.memberId != actingMember && p.status == MemberStatus.active)
            ReachablePerson(
              workspaceId: id,
              workspaceName: name,
              id: p.userId,
              name: p.name,
            ),
  ];
}

/// The group's id, title and members (Ada, Bruno, Chiara).
@visibleForTesting
const demoGroupId = 'demo-group-market';
const _groupTitle = 'Market day lunch';

/// [messenger] with the group, its roster, a first message and its inbox
/// row.
FakeMessengerRepository withDemoGroup(
  FakeMessengerRepository messenger,
  DateTime now,
) {
  final members = demoCast.take(3).toList();
  final at = now.subtract(const Duration(hours: 3));
  const body = 'Saturday at noon, the usual table?';
  messenger
    ..groups[demoGroupId] = AccountGroupInfo(
      id: demoGroupId,
      title: _groupTitle,
      memberCount: members.length,
    )
    ..groupRoster[demoGroupId] = [
      for (final p in members)
        GroupMember(userId: p.userId, name: p.name, isAdmin: p.isOwner),
    ]
    ..threads[FakeMessengerRepository.threadKey(
      MessageContextKind.accountGroup,
      demoGroupId,
    )] = [
      ContextMessage(
        id: '$demoGroupId-1',
        kind: MessageKind.groupMessage,
        body: body,
        mine: false,
        authorName: members[2].name,
        createdAt: at,
      ),
    ]
    ..inboxRows.add({
      'context_kind': MessageContextKind.accountGroup.wire,
      'context_id': demoGroupId,
      'title': _groupTitle,
      'last_body': body,
      'last_at': at.toUtc().toIso8601String(),
      'unread': 0,
      'member_count': members.length,
    });
  return messenger;
}
