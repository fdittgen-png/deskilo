// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/status_colors.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
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

/// In-memory [ThemeStore] (same seam as theme_selection_test.dart) so the
/// #196 dark-theme test never touches SharedPreferences.
class InMemoryThemeStore implements ThemeStore {
  InMemoryThemeStore({this.mode});

  String? mode;

  @override
  Future<String?> read() async => mode;

  @override
  Future<void> write(String? mode) async => this.mode = mode;
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
  String? themeMode,
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
      overrides: [
        ...standardTestOverrides(
          events: events,
          floorPlan: plans,
          workspace: workspace,
        ),
        themeStoreProvider
            .overrideWithValue(InMemoryThemeStore(mode: themeMode)),
      ],
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
    await tester.tap(find.byTooltip('Events'));
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
    await tester.tap(find.byTooltip('Events'));
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
    await tester.tap(find.byTooltip('Events'));
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
    expect(find.textContaining('Validated by Bo'), findsOneWidget);
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
    expect(find.textContaining('Validated by Flo'), findsOneWidget);
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

    expect(find.textContaining('Validated by Flo'), findsOneWidget);
    expect(find.textContaining('Validated by System'), findsOneWidget);
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

  group('semantic validation colors (#196)', () {
    EventDecision decision({
      required String id,
      required bool accept,
      String? memberId,
      String eventId = 'evt-1',
    }) =>
        EventDecision(
          id: id,
          eventId: eventId,
          memberId: memberId,
          accept: accept,
          decidedBySystem: false,
          decidedAt: DateTime.utc(2026, 7, 8, 9),
        );

    testWidgets(
        'feed decision rows show a green check for accepts and a red '
        'cross for refusals; a rejected event gets a red cross trailing',
        (tester) async {
      // Quorum story: Bo accepted, Flo declined → the event is rejected.
      await pumpEvents(
        tester,
        seed: [
          event(
            actor: 'member-2',
            subject: 'member-1',
            status: EventStatus.rejected,
          ),
        ],
        decisions: [
          decision(id: 'dec-1', accept: true, memberId: 'member-3'),
          decision(id: 'dec-2', accept: false, memberId: 'member-1'),
        ],
      );

      // Accepted decision: green outlined check + localized text.
      final check =
          tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(check.color, AppStatusColors.success);
      expect(find.textContaining('Validated by Bo'), findsOneWidget);

      // Refused decision row AND the rejected trailing: red crosses.
      final error = Theme.of(
        tester.element(find.byIcon(Icons.check_circle_outline)),
      ).colorScheme.error;
      final crosses =
          tester.widgetList<Icon>(find.byIcon(Icons.cancel_outlined));
      expect(crosses, hasLength(2));
      for (final cross in crosses) {
        expect(cross.color, error);
      }
      expect(find.textContaining('Declined by Flo'), findsOneWidget);
    });

    testWidgets('an applied feed row carries a green check trailing',
        (tester) async {
      await pumpEvents(tester, seed: [event()]);

      final check =
          tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(check.color, AppStatusColors.success);
      expect(find.byIcon(Icons.hourglass_top), findsNothing);
    });

    testWidgets(
        'the pending card colors Accept green and Decline red with their '
        'check/cross icons', (tester) async {
      await pumpEvents(
        tester,
        seed: [
          event(
            actor: 'member-2',
            subject: 'member-1',
            status: EventStatus.pending,
          ),
        ],
      );

      // FilledButton.icon / TextButton.icon build private subtypes, so
      // find.byType (exact runtimeType) misses them — use bySubtype.
      final acceptFinder = find.ancestor(
        of: find.text('Accept'),
        matching: find.bySubtype<FilledButton>(),
      );
      final accept = tester.widget<FilledButton>(acceptFinder);
      expect(
        accept.style?.backgroundColor?.resolve(const <WidgetState>{}),
        AppStatusColors.success,
      );
      expect(
        accept.style?.foregroundColor?.resolve(const <WidgetState>{}),
        AppStatusColors.onSuccess,
      );
      expect(
        find.descendant(of: acceptFinder, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      final declineFinder = find.ancestor(
        of: find.text('Decline'),
        matching: find.bySubtype<TextButton>(),
      );
      final decline = tester.widget<TextButton>(declineFinder);
      final error =
          Theme.of(tester.element(declineFinder)).colorScheme.error;
      expect(
        decline.style?.foregroundColor?.resolve(const <WidgetState>{}),
        error,
      );
      expect(
        find.descendant(of: declineFinder, matching: find.byIcon(Icons.close)),
        findsOneWidget,
      );
    });

    testWidgets(
        'the dark theme uses the lighter success tint on decisions, '
        'trailing marks and the Accept button', (tester) async {
      await pumpEvents(
        tester,
        themeMode: 'dark',
        seed: [
          event(
            actor: 'member-2',
            subject: 'member-1',
            status: EventStatus.pending,
          ),
          event(id: 'evt-2', status: EventStatus.confirmed),
        ],
        decisions: [
          decision(
            id: 'dec-1',
            accept: true,
            memberId: 'member-3',
            eventId: 'evt-2',
          ),
        ],
      );

      final accept = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Accept'),
          matching: find.bySubtype<FilledButton>(),
        ),
      );
      expect(
        accept.style?.backgroundColor?.resolve(const <WidgetState>{}),
        AppStatusColors.successDark,
      );
      expect(
        accept.style?.foregroundColor?.resolve(const <WidgetState>{}),
        AppStatusColors.onSuccessDark,
      );

      // Decision row + confirmed trailing: both carry the dark tint.
      final checks =
          tester.widgetList<Icon>(find.byIcon(Icons.check_circle_outline));
      expect(checks, hasLength(2));
      for (final icon in checks) {
        expect(icon.color, AppStatusColors.successDark);
      }
    });
  });
}
