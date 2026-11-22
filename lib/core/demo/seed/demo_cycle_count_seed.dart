// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4295 -- the Demo's high-value shelf plan made its task nine days ago and it is still open past the
// business's overdue days, so the owner has been told once, as the server tells it: the inbox row names
// the plan and opens the cycle counts, where the open task is.
import '../../../features/events/domain/workspace_event.dart';
import '../data/event_repository.dart';

/// Adds the overdue notice of the Demo's open cycle count task to [events].
void seedDemoCycleCountOverdue(FakeEventRepository events, DateTime now) => events.events.add(
  WorkspaceEvent(
    id: 'demo-count-overdue-1',
    workspaceId: 'ws-1',
    type: EventType.stockCountOverdue,
    action: EventAction.created,
    actorMemberId: 'member-1',
    subjectMemberId: 'member-1',
    payload: {'task': 'demo-count-task-1', 'plan': 'High-value shelf', 'due_on': now.subtract(const Duration(days: 9)).toIso8601String().substring(0, 10)},
    status: EventStatus.applied,
    createdAt: now.subtract(const Duration(days: 1)),
  ),
);
