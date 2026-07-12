// SPDX-License-Identifier: MIT
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

Finder tabLabeled(WidgetTester tester, String label) => find.byWidget(
      tester
          .widgetList<ShellBarTab>(find.byType(ShellBarTab))
          .firstWhere((t) => t.destination.label == label),
    );

void main() {
  testWidgets('disabled Money and Calendar features drop their tabs',
      (tester) async {
    await pumpWithFlags(
      tester,
      const {'moneyTab': false, 'calendarTab': false},
    );

    expect(tabLabels(tester), ['Plan', 'Events']);
  });

  testWidgets('all features on keeps the four tabs', (tester) async {
    await pumpWithFlags(tester, const {});

    expect(tabLabels(tester), ['Plan', 'Calendar', 'Events', 'Money']);
  });

  testWidgets(
      'with Calendar disabled the pending badge still lands on Events '
      'and tapping it opens the Events branch', (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([pendingForMe('e1'), pendingForMe('e2')]);
    await pumpWithFlags(tester, const {'calendarTab': false}, events: events);

    // The badge renders inside the Events destination, not a neighbor.
    expect(
      find.descendant(
        of: tabLabeled(tester, 'Events'),
        matching: find.text('2'),
      ),
      findsWidgets,
    );

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Events'),
    );
    expect(appBarTitle, findsOneWidget);
  });

  testWidgets('everything gated off leaves Plan without a bottom bar',
      (tester) async {
    await pumpWithFlags(
      tester,
      const {'calendarTab': false, 'eventsTab': false, 'moneyTab': false},
    );

    expect(find.byType(ShellBottomBar), findsNothing);
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Plan'),
    );
    expect(appBarTitle, findsOneWidget);
  });
}
