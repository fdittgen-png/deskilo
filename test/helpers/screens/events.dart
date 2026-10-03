// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1864 C — the events screen (with its event fixtures) pump, moved out of `test/features/events/events_screen_test.dart`:
// the accessibility matrix, the locale walk and the other suites that
// reuse it import this helper instead of a whole test file.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../fake_event_repository.dart';
import '../fake_floor_plan_repository.dart';
import '../mock_providers.dart';
import '../navigation.dart';

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
    createdAt: kTestNow,
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
    createdAt: kTestNow,
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
  await openAlertsTab(tester);
  return events;
}
