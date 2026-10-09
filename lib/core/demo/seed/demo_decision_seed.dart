// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the decisions a visitor can demonstrate: requests of several
// kinds waiting for a validator, a history of settled ones (confirmed
// and refused, with who decided), and the validation rules behind them.
// Dov's request to join stays the first one (demo_dataset.dart).
import '../../../features/events/domain/event_decision.dart';
import '../../../features/events/domain/validation_policy.dart';
import '../../../features/events/domain/workspace_event.dart';
import '../data/event_repository.dart';

void seedDemoDecisions(FakeEventRepository events, DateTime now) {
  final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  WorkspaceEvent event(
    String id,
    EventType type,
    String actor,
    Map<String, dynamic> payload, {
    String? subject,
    EventStatus status = EventStatus.pending,
    EventAction action = EventAction.submitted,
    int hoursAgo = 3,
    String? reservationId,
  }) => WorkspaceEvent(
    id: id,
    workspaceId: 'ws-1',
    type: type,
    action: action,
    actorMemberId: actor,
    subjectMemberId: subject ?? actor,
    reservationId: reservationId,
    payload: payload,
    status: status,
    createdAt: now.subtract(Duration(hours: hoursAgo)),
    decidedAt: status == EventStatus.pending
        ? null
        : now.subtract(Duration(hours: hoursAgo - 1)),
  );

  events.events.addAll([
    // Waiting for a decision.
    event('demo-quota', EventType.quota, 'member-2', {
      'half_days': 4,
      'period': period,
    }, hoursAgo: 5),
    event('demo-expense', EventType.expense, 'member-3', {
      'amount_cents': 2450,
      'supply': {'name': 'Printer paper', 'quantity': 5},
    }, hoursAgo: 20),
    event('demo-service-charge', EventType.serviceCharge, 'member-2', {
      'name': 'Coffee',
      'quantity': 6,
      'amount_cents': 900,
    }, hoursAgo: 26),
    event(
      'demo-negotiation',
      EventType.priceNegotiation,
      'member-1',
      {'subscription_pct': 50, 'fee_cents': 8000, 'discount_percent': 10},
      subject: 'member-2',
      hoursAgo: 30,
    ),
    event(
      'demo-delete-request',
      EventType.reservationDelete,
      'member-2',
      {
        'starts_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'was_checked_in': false,
      },
      reservationId: 'demo-past',
      hoursAgo: 8,
    ),
    // Settled: what the history and the audit show.
    event(
      'demo-quota-done',
      EventType.quota,
      'member-3',
      {'half_days': 2, 'period': period},
      status: EventStatus.confirmed,
      hoursAgo: 72,
    ),
    event(
      'demo-expense-refused',
      EventType.expense,
      'member-2',
      {
        'amount_cents': 8900,
        'supply': {'name': 'Desk lamp', 'quantity': 1},
      },
      status: EventStatus.rejected,
      hoursAgo: 96,
    ),
  ]);

  EventDecision decision(
    String id,
    String event,
    String member,
    bool ok,
    int hoursAgo,
  ) => EventDecision(
    id: id,
    eventId: event,
    memberId: member,
    accept: ok,
    decidedBySystem: false,
    decidedAt: now.subtract(Duration(hours: hoursAgo)),
  );
  events.decisions.addAll([
    decision('demo-decision-1', 'demo-quota-done', 'member-1', true, 71),
    decision('demo-decision-2', 'demo-expense-refused', 'member-1', false, 95),
    // One of the two validations a negotiation needs is already given.
    decision('demo-decision-3', 'demo-negotiation', 'member-3', true, 29),
  ]);

  // The rules: expenses need one admin, a negotiation two validations.
  events.policies.addAll(const [
    ValidationPolicy(
      id: 'demo-policy-expense',
      workspaceId: 'ws-1',
      eventType: 'expense',
      requiredCount: 1,
      adminsMayValidate: true,
      eligibleAdminIds: [],
      ownerRequired: false,
    ),
    ValidationPolicy(
      id: 'demo-policy-negotiation',
      workspaceId: 'ws-1',
      eventType: 'price_negotiation',
      requiredCount: 2,
      adminsMayValidate: true,
      eligibleAdminIds: [],
      ownerRequired: true,
    ),
  ]);
}
