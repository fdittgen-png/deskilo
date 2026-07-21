// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';

Future<void> pumpWithFlags(
  WidgetTester tester,
  Map<String, dynamic> featureFlags, {
  FakeEventRepository? events,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace:
            FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
        events: events,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

WorkspaceEvent pendingForMe(String id) => WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: EventType.reservation,
      action: EventAction.created,
      actorMemberId: 'member-2',
      subjectMemberId: 'member-1',
      payload: const {},
      status: EventStatus.pending,
      createdAt: DateTime.now(),
    );

List<String> tabLabels(WidgetTester tester) => tester
    .widgetList<ShellBarTab>(find.byType(ShellBarTab))
    .map((t) => t.destination.label)
    .toList();

void main() {
  testWidgets('disabled Money and Calendar features drop their tabs',
      (tester) async {
    await pumpWithFlags(
      tester,
      const {'moneyTab': false, 'calendarTab': false},
    );

    expect(tabLabels(tester), ['Plan', 'Members']);
  });

  testWidgets('all features on keeps the four tabs', (tester) async {
    await pumpWithFlags(tester, const {});

    expect(tabLabels(tester), ['Plan', 'Calendar', 'Members', 'Money']);
  });

  testWidgets(
      'with Calendar disabled the pending badge still lands on the '
      'app-bar bell and tapping it opens the events feed (#230)',
      (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([pendingForMe('e1'), pendingForMe('e2')]);
    await pumpWithFlags(tester, const {'calendarTab': false}, events: events);

    // The badge renders inside the bell action, not a neighbor.
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Events'),
    );
    expect(appBarTitle, findsOneWidget);
  });

  testWidgets(
      'everything gated off keeps Plan and the ungated Members tab — the '
      'bar stays, the bell goes (#230)', (tester) async {
    await pumpWithFlags(
      tester,
      const {'calendarTab': false, 'eventsTab': false, 'moneyTab': false},
    );

    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(tabLabels(tester), ['Plan', 'Members']);
    expect(find.byTooltip('Events'), findsNothing);
    // The app boots on the Reserve hub (its branch is never gated).
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Reserve'),
    );
    expect(appBarTitle, findsOneWidget);
  });
}
