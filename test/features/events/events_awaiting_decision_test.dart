// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pending section of the Alerts feed lists exactly the events the
// signed-in member may decide now: in feed order, never one they have
// already decided, and nothing when nobody is signed in.
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member(String id, {bool owner = false}) => Member(
  id: id,
  workspaceId: 'ws-1',
  userId: 'u-$id',
  isAdmin: owner,
  isOwner: owner,
  status: MemberStatus.active,
);

WorkspaceEvent _event(
  String id, {
  String actor = 'm-other',
  EventStatus status = EventStatus.pending,
}) => WorkspaceEvent(
  id: id,
  workspaceId: 'ws-1',
  type: EventType.expense,
  action: EventAction.submitted,
  actorMemberId: actor,
  subjectMemberId: actor,
  payload: const {},
  status: status,
  createdAt: DateTime.utc(2026, 7, 8),
);

EventDecision _decision(String eventId, String memberId) => EventDecision(
  id: 'd-$eventId-$memberId',
  eventId: eventId,
  memberId: memberId,
  accept: true,
  decidedBySystem: false,
  decidedAt: DateTime.utc(2026, 7, 9),
);

void main() {
  final owner = _member('m-owner', owner: true);
  final worker = _member('m-worker');
  final events = [
    _event('e-open'),
    _event('e-mine', actor: 'm-owner'),
    _event('e-done', status: EventStatus.applied),
    _event('e-decided'),
    _event('e-second'),
  ];
  final decisions = {
    'e-decided': [_decision('e-decided', 'm-owner')],
    'e-second': [_decision('e-second', 'm-someone')],
  };

  final cases = <(String, Member?, List<String>)>[
    ('nobody signed in decides nothing', null, []),
    ('a worker decides no expense', worker, []),
    (
      'the owner: open ones in feed order, not own, not settled, not decided',
      owner,
      ['e-open', 'e-second'],
    ),
  ];

  for (final (name, me, expected) in cases) {
    test(name, () {
      final pending = eventsAwaitingDecisionBy(
        me,
        events,
        policies: const <ValidationPolicy>[],
        decisions: decisions,
      );
      expect([for (final e in pending) e.id], expected);
    });
  }
}
