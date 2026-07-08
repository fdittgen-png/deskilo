// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
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

Future<FakeEventRepository> pumpEvents(
  WidgetTester tester, {
  List<WorkspaceEvent> seed = const [],
}) async {
  final events = FakeEventRepository()..events.addAll(seed);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
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
}
