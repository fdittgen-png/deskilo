// SPDX-License-Identifier: 0BSD
//
// #598 — optional regrouping of the mixed notification feed: by type,
// by calendar day or by acting member. The choice persists like the
// #581 filter; every group header carries the grouping symbol and one
// tap on it returns to the flat list. Flag OFF removes the control AND
// ignores an older persisted grouping.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/storage/notification_filter_store.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

WorkspaceEvent _event(
  String id, {
  required String actor,
  required DateTime at,
  EventType type = EventType.reservation,
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.created,
      actorMemberId: actor,
      subjectMemberId: actor,
      payload: const {'seat_id': 'seat-4'},
      status: EventStatus.applied,
      createdAt: at,
    );

/// Two events on two days, by two members, in two categories — enough
/// to fold along every axis. Returns the persisted-filter store so
/// tests can assert what a "restart" would read back.
Future<InMemoryNotificationFilterStore> pumpFeed(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  InMemoryNotificationFilterStore? store,
}) async {
  final events = FakeEventRepository()
    ..events.addAll([
      _event('evt-res', actor: 'member-1', at: kTestNow),
      _event(
        'evt-pay',
        actor: 'member-2',
        at: kTestNow.subtract(const Duration(days: 1)),
        type: EventType.payment,
      ),
    ]);
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags)
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
  final filters = store ?? InMemoryNotificationFilterStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: workspace,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
        notificationFilters: filters,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await openAlertsTab(tester);
  return filters;
}

void main() {
  testWidgets(
      'group by type folds the feed under one symbol-fronted header per '
      'category, and the choice persists', (tester) async {
    final store = await pumpFeed(tester);
    expect(find.byTooltip('Ungroup'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notif-group-type')));
    await tester.pumpAndSettle();

    final reservations =
        find.byKey(const ValueKey('notif-ungroup-reservations'));
    expect(reservations, findsOneWidget);
    expect(
      find.byKey(const ValueKey('notif-ungroup-money')),
      findsOneWidget,
    );
    // The header shows the grouping SYMBOL — the ungroup affordance.
    expect(
      find.descendant(
        of: reservations,
        matching: find.byIcon(Icons.category_outlined),
      ),
      findsOneWidget,
    );
    // Persisted exactly like the #581 filter.
    expect(
      NotificationFilterState.decode(store.filter).grouping,
      FeedGrouping.type,
    );
  });

  testWidgets('group by date folds by calendar day', (tester) async {
    await pumpFeed(tester);

    await tester.tap(find.byKey(const ValueKey('notif-group-date')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notif-ungroup-2026-05-13')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('notif-ungroup-2026-05-12')),
      findsOneWidget,
    );
  });

  testWidgets('group by user folds by acting member', (tester) async {
    await pumpFeed(tester);

    await tester.tap(find.byKey(const ValueKey('notif-group-user')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('notif-ungroup-member-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('notif-ungroup-member-2')),
      findsOneWidget,
    );
  });

  testWidgets(
      'ONE tap on the header symbol ungroups back to the flat list — '
      'and the control stays put for regrouping', (tester) async {
    final store = await pumpFeed(tester);
    await tester.tap(find.byKey(const ValueKey('notif-group-user')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ungroup'), findsNWidgets(2));

    await tester
        .tap(find.byKey(const ValueKey('notif-ungroup-member-1')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ungroup'), findsNothing);
    expect(
      NotificationFilterState.decode(store.filter).grouping,
      FeedGrouping.none,
    );
    // The chip line is still there — regrouping is one tap away.
    expect(
      find.byKey(const ValueKey('notif-group-user')),
      findsOneWidget,
    );
  });

  testWidgets(
      'the persisted grouping greets the user on the next app start',
      (tester) async {
    final store = InMemoryNotificationFilterStore()
      ..filter = const NotificationFilterState(
        grouping: FeedGrouping.type,
      ).encode();

    await pumpFeed(tester, store: store);

    expect(
      find.byKey(const ValueKey('notif-ungroup-reservations')),
      findsOneWidget,
    );
  });

  testWidgets(
      'flag OFF hides the grouping control and forces the flat list '
      'even over an older persisted choice', (tester) async {
    final store = InMemoryNotificationFilterStore()
      ..filter = const NotificationFilterState(
        grouping: FeedGrouping.type,
      ).encode();

    await pumpFeed(
      tester,
      featureFlags: const {'notificationGrouping': false},
      store: store,
    );

    expect(
      find.byKey(const ValueKey('notif-group-type')),
      findsNothing,
    );
    expect(find.byTooltip('Ungroup'), findsNothing);
  });
}
