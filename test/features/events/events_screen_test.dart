// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

WorkspaceEvent event({
  String id = 'evt-1',
  EventAction action = EventAction.created,
  EventStatus status = EventStatus.applied,
  String actor = 'member-1',
  String subject = 'member-1',
  EventType type = EventType.reservation,
}) {
  return WorkspaceEvent(
    id: id,
    workspaceId: 'ws-1',
    type: type,
    action: action,
    actorMemberId: actor,
    subjectMemberId: subject,
    reservationId: 'res-1',
    payload: const {
      'starts_at': '2026-07-08T09:00:00Z',
      'ends_at': '2026-07-08T17:00:00Z',
      'seat_id': 'seat-4',
    },
    status: status,
    createdAt: DateTime.now(),
  );
}

WorkspaceEvent serviceChargeEvent({
  String id = 'evt-svc',
  String actor = 'member-1',
  String subject = 'member-1',
  EventStatus status = EventStatus.pending,
}) {
  return WorkspaceEvent(
    id: id,
    workspaceId: 'ws-1',
    type: EventType.serviceCharge,
    action: EventAction.submitted,
    actorMemberId: actor,
    subjectMemberId: subject,
    payload: const {
      'service_id': 'service-coffee',
      'name': 'Coffee',
      'price_cents': 150,
      'quantity': 2,
      'amount_cents': 300,
      'period': '2026-07',
    },
    status: status,
    createdAt: DateTime.now(),
  );
}

Member adminMember(String id) => Member(
      id: id,
      workspaceId: 'ws-1',
      userId: 'user-$id',
      isAdmin: true,
      isOwner: false,
      status: MemberStatus.active,
    );

Future<FakeEventRepository> pumpEvents(
  WidgetTester tester, {
  List<WorkspaceEvent> seed = const [],
  List<EventDecision> decisions = const [],
  List<ValidationPolicy> policies = const [],
  List<Member> otherMembers = const [],
}) async {
  final events = FakeEventRepository()
    ..events.addAll(seed)
    ..decisions.addAll(decisions)
    ..policies.addAll(policies);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana', 'member-3': 'Bo'}
    ..otherMembers.addAll(otherMembers);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        floorPlan: plans,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Events'));
  await tester.pumpAndSettle();
  return events;
}

void main() {
  testWidgets(
      'an expense pending card is NOT offered to its submitter (bug #107)',
      (tester) async {
    // Viewer member-1 is an admin AND the expense submitter; member-2 is
    // another active admin → the other admin decides, not the submitter.
    final events = FakeEventRepository()
      ..events.add(
        event(
          id: 'evt-exp',
          type: EventType.expense,
          action: EventAction.submitted,
          actor: 'member-1',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      );
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: true,
          isOwner: false,
          status: MemberStatus.active,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          events: events,
          workspace: workspace,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for your confirmation'), findsNothing);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('a solo admin may decide their own expense (escape hatch)',
      (tester) async {
    final events = FakeEventRepository()
      ..events.add(
        event(
          id: 'evt-exp',
          type: EventType.expense,
          action: EventAction.submitted,
          actor: 'member-1',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(events: events),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('the feed narrates a self-service booking', (tester) async {
    await pumpEvents(tester, seed: [event()]);

    expect(find.text('Flo booked A1'), findsOneWidget);
  });

  testWidgets('admin-for-other events carry the for-subject suffix',
      (tester) async {
    await pumpEvents(
      tester,
      seed: [
        event(actor: 'member-2', subject: 'member-1', status: EventStatus.confirmed),
      ],
    );

    expect(find.text('Ana booked A1 for Flo'), findsOneWidget);
  });

  testWidgets('pending event for me is pinned and can be accepted',
      (tester) async {
    final repo = await pumpEvents(
      tester,
      seed: [
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      ],
    );

    expect(find.text('Waiting for your confirmation'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.events.single.status, EventStatus.confirmed);
    expect(find.text('Waiting for your confirmation'), findsNothing);
  });

  testWidgets('declining a pending event rejects it', (tester) async {
    final repo = await pumpEvents(
      tester,
      seed: [
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      ],
    );

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(repo.events.single.status, EventStatus.rejected);
  });

  testWidgets(
      'a pending service charge added by an admin is pinned for the '
      'subject with name, quantity and amount (#129)', (tester) async {
    final repo = await pumpEvents(
      tester,
      seed: [serviceChargeEvent(actor: 'member-2', subject: 'member-1')],
    );

    expect(find.text('Waiting for your confirmation'), findsOneWidget);
    expect(find.text('Coffee ×2 — €3.00 for Flo'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(repo.events.single.status, EventStatus.confirmed);
  });

  testWidgets(
      'a self-reported service charge is NOT offered to its reporter '
      'while another admin exists (#129)', (tester) async {
    // Viewer member-1 is an admin AND the reporter; member-2 is another
    // active admin → the other admin decides, not the reporter.
    final events = FakeEventRepository()
      ..events.add(serviceChargeEvent());
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: true,
          isOwner: false,
          status: MemberStatus.active,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          events: events,
          workspace: workspace,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for your confirmation'), findsNothing);
    expect(find.text('Accept'), findsNothing);
    // The charge still appears in the feed, marked as pending.
    expect(find.text('Coffee ×2 — €3.00 for Flo'), findsOneWidget);
  });

  testWidgets(
      'a pending card shows validator checkmarks and quorum progress (#130)',
      (tester) async {
    // Ana (member-2) submitted an expense; the workspace default policy
    // wants 2 accepts and admin Bo (member-3) already gave one. Viewer
    // Flo (owner) is the missing validator.
    await pumpEvents(
      tester,
      seed: [
        event(
          id: 'evt-exp',
          type: EventType.expense,
          action: EventAction.submitted,
          actor: 'member-2',
          subject: 'member-2',
          status: EventStatus.pending,
        ),
      ],
      policies: [
        const ValidationPolicy(
          workspaceId: 'ws-1',
          requiredCount: 2,
          adminsMayValidate: true,
          eligibleAdminIds: [],
          ownerRequired: false,
        ),
      ],
      decisions: [
        EventDecision(
          id: 'dec-1',
          eventId: 'evt-exp',
          memberId: 'member-3',
          accept: true,
          decidedBySystem: false,
          decidedAt: DateTime.now(),
        ),
      ],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    expect(find.text('Waiting for your confirmation'), findsOneWidget);
    expect(find.textContaining('✓ Validated by Bo'), findsOneWidget);
    expect(find.textContaining('1/2 validations'), findsOneWidget);
  });

  testWidgets(
      'an accept below the quorum keeps the event pending and moves it '
      'off my pile (#130)', (tester) async {
    final repo = await pumpEvents(
      tester,
      seed: [
        event(
          id: 'evt-exp',
          type: EventType.expense,
          action: EventAction.submitted,
          actor: 'member-2',
          subject: 'member-2',
          status: EventStatus.pending,
        ),
      ],
      policies: [
        const ValidationPolicy(
          workspaceId: 'ws-1',
          requiredCount: 2,
          adminsMayValidate: true,
          eligibleAdminIds: [],
          ownerRequired: false,
        ),
      ],
      otherMembers: [adminMember('member-2'), adminMember('member-3')],
    );

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // 1 of 2 accepts: still pending server-side, no longer offered to me,
    // and the feed narrates my decision plus the quorum progress.
    expect(repo.events.single.status, EventStatus.pending);
    expect(find.text('Accept'), findsNothing);
    expect(find.textContaining('✓ Validated by Flo'), findsOneWidget);
    expect(find.textContaining('1/2 validations'), findsOneWidget);
  });

  testWidgets(
      'a confirmed feed card lists who validated, including a System '
      'sweep row (#130)', (tester) async {
    await pumpEvents(
      tester,
      seed: [
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.confirmed,
        ),
      ],
      decisions: [
        EventDecision(
          id: 'dec-1',
          eventId: 'evt-1',
          memberId: 'member-1',
          accept: true,
          decidedBySystem: false,
          decidedAt: DateTime.utc(2026, 7, 8, 9),
        ),
        EventDecision(
          id: 'dec-2',
          eventId: 'evt-1',
          memberId: null,
          accept: true,
          decidedBySystem: true,
          decidedAt: DateTime.utc(2026, 7, 9, 3),
        ),
      ],
    );

    expect(find.textContaining('✓ Validated by Flo'), findsOneWidget);
    expect(find.textContaining('✓ Validated by System'), findsOneWidget);
  });

  testWidgets('type filter narrows the feed', (tester) async {
    await pumpEvents(
      tester,
      seed: [
        event(),
        event(id: 'evt-2', type: EventType.payment),
      ],
    );

    expect(find.text('Flo booked A1'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Payment'));
    await tester.pumpAndSettle();

    expect(find.text('Flo booked A1'), findsNothing);
  });

  testWidgets('pull-to-refresh surfaces events created elsewhere (#111)',
      (tester) async {
    final repo = await pumpEvents(tester);
    expect(find.text('No events yet.'), findsOneWidget);

    repo.events.add(event());
    await tester.fling(
      find.text('No events yet.'),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Flo booked A1'), findsOneWidget);
  });
}
