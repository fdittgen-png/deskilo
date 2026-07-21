// SPDX-License-Identifier: 0BSD
//
// Screen-level quorum matrix (#134, epic #121): the #130 policy rules are
// unit-tested in event_decider_test; these pin the events SCREEN wiring —
// which policy row it resolves, whom it offers buttons to, and what a
// decision does to the pending pile.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';

WorkspaceEvent expenseEvent({
  String id = 'evt-exp',
  String actor = 'member-2',
  EventType type = EventType.expense,
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.submitted,
      actorMemberId: actor,
      subjectMemberId: actor,
      payload: const {'amount_cents': 20000},
      status: EventStatus.pending,
      createdAt: DateTime.now(),
    );

Member adminMember(String id) => Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'user-$id',
      isAdmin: true,
      isOwner: false,
      status: MemberStatus.active,
    );

ValidationPolicy policy({
  String? eventType,
  int requiredCount = 2,
  bool adminsMayValidate = true,
  List<String> eligibleAdminIds = const [],
  bool ownerRequired = false,
}) =>
    ValidationPolicy(
      workspaceId: 'ws-1',
      eventType: eventType,
      requiredCount: requiredCount,
      adminsMayValidate: adminsMayValidate,
      eligibleAdminIds: eligibleAdminIds,
      ownerRequired: ownerRequired,
    );

EventDecision acceptBy(String memberId, {String eventId = 'evt-exp'}) =>
    EventDecision(
      id: 'dec-$memberId',
      eventId: eventId,
      memberId: memberId,
      accept: true,
      decidedBySystem: false,
      decidedAt: DateTime.now(),
    );

/// Pumps the Events tab. The viewer is member-1 — the workspace owner by
/// default; pass [viewerIsOwner]: false to demote them to a plain admin.
Future<FakeEventRepository> pumpEvents(
  WidgetTester tester, {
  List<WorkspaceEvent> seed = const [],
  List<EventDecision> decisions = const [],
  List<ValidationPolicy> policies = const [],
  List<Member> otherMembers = const [],
  bool viewerIsOwner = true,
}) async {
  final events = FakeEventRepository()
    ..events.addAll(seed)
    ..decisions.addAll(decisions)
    ..policies.addAll(policies);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana', 'member-3': 'Bo'}
    ..otherMembers.addAll(otherMembers);
  if (!viewerIsOwner) {
    workspace.myMember = workspace.myMember.copyWith(isOwner: false);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(events: events, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  // #230: the events feed is behind the app-bar bell, no longer a tab.
  await tester.tap(find.byTooltip('Events'));
  await tester.pumpAndSettle();
  return events;
}

void main() {
  testWidgets(
      'the second accept reaches the required_count 2 quorum and confirms '
      'the event', (tester) async {
    // Guards: the screen's Accept must complete a partially validated
    // quorum instead of starting a fresh count.
    final repo = await pumpEvents(
      tester,
      seed: [expenseEvent()],
      policies: [policy()],
      decisions: [acceptBy('member-3')],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    expect(find.textContaining('1/2 validations'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.events.single.status, EventStatus.confirmed);
    expect(find.text('Waiting for your confirmation'), findsNothing);
    expect(find.textContaining('Validated by Flo'), findsOneWidget);
    expect(find.textContaining('Validated by Bo'), findsOneWidget);
  });

  testWidgets(
      'a decline closes a quorum event immediately, despite a prior accept',
      (tester) async {
    // Guards: rejection is not a vote — one veto ends the protocol even
    // when the accept count is still below the quorum.
    final repo = await pumpEvents(
      tester,
      seed: [expenseEvent()],
      policies: [policy()],
      decisions: [acceptBy('member-3')],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(repo.events.single.status, EventStatus.rejected);
    expect(find.text('Waiting for your confirmation'), findsNothing);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets(
      'owner_required: after an admin accept the event stays pending and '
      'the owner is still offered the buttons', (tester) async {
    // Guards: an owner-required policy must keep the card on the owner's
    // pile after admin accepts — dropping it would strand the event.
    final repo = await pumpEvents(
      tester,
      seed: [expenseEvent()],
      policies: [policy(ownerRequired: true)],
      decisions: [acceptBy('member-3')],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    expect(repo.events.single.status, EventStatus.pending);
    expect(find.text('Waiting for your confirmation'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.textContaining('Validated by Bo'), findsOneWidget);
    expect(find.textContaining('1/2 validations'), findsOneWidget);
  });

  testWidgets(
      'an admin excluded by eligible_admin_ids sees the feed row but no '
      'buttons', (tester) async {
    // Guards: the screen must pass the policy's eligibility to the
    // decider — an unlisted admin gets no Accept/Decline.
    await pumpEvents(
      tester,
      seed: [expenseEvent()],
      policies: [policy(requiredCount: 1, eligibleAdminIds: ['member-3'])],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
      viewerIsOwner: false,
    );

    expect(find.text('Waiting for your confirmation'), findsNothing);
    expect(find.text('Accept'), findsNothing);
    // Still audited in the feed, marked pending.
    expect(find.textContaining('Ana submitted an expense'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
  });

  testWidgets(
      'a type-specific policy row is matched by its DB name: a '
      'service_charge quorum applies to service-charge cards only',
      (tester) async {
    // Guards: the screen resolves policies via EventType.dbName
    // ('service_charge'), not the Dart enum name ('serviceCharge').
    await pumpEvents(
      tester,
      seed: [
        expenseEvent(
          id: 'evt-svc',
          actor: 'member-2',
          type: EventType.serviceCharge,
        ).copyWith(
          subjectMemberId: 'member-1',
          payload: const {
            'name': 'Coffee',
            'quantity': 2,
            'amount_cents': 300,
            'period': '2026-07',
          },
        ),
        expenseEvent(id: 'evt-exp', actor: 'member-2'),
      ],
      policies: [policy(eventType: 'service_charge')],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    // The service charge card carries the 0/2 quorum progress; the
    // expense (workspace default: one decision) shows none.
    expect(find.textContaining('0/2 validations'), findsOneWidget);
    expect(find.textContaining('0/1 validations'), findsNothing);
  });
}
