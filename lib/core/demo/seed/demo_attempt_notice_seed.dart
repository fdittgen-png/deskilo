// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4136 — Bruno paid last month's open bill online at Mollie and the
// reconciliation could not reach Mollie to check it: Ada, who reads the
// finances, is told which payment, whose and why, and opens Bruno's account
// from it. Bruno, without the right, does not read it.
import '../../../features/events/domain/workspace_event.dart';
import '../data/event_repository.dart';
import 'demo_history_seed.dart';

/// The notice of Bruno's payment attempt that could not be checked.
WorkspaceEvent _demoUnreadableAttempt(DateTime now) {
  final lastMonth = DateTime(now.year, now.month - 1, 28);
  return WorkspaceEvent(
    id: 'demo-attempt-unreadable',
    workspaceId: 'ws-1',
    type: EventType.paymentAttemptUnreadable,
    action: EventAction.created,
    actorMemberId: 'member-1',
    subjectMemberId: 'member-1',
    payload: {
      'intent': 'demo-intent-bruno',
      'member_id': 'member-2',
      'reference': 'PAY-${now.year}-0007',
      'provider': 'mollie',
      'amount_cents': demoMonthlyCents(9000, lastMonth.year, now),
      'currency': 'EUR',
      'reason': 'unreachable',
    },
    status: EventStatus.applied,
    createdAt: now.subtract(const Duration(hours: 3)),
  );
}

/// Adds the notice to the Demo's [events].
void seedDemoAttemptNotice(FakeEventRepository events, DateTime now) =>
    events.events.add(_demoUnreadableAttempt(now));
