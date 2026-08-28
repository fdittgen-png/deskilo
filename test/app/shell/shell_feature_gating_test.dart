// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

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
      createdAt: kTestNow,
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

    // #702 — Members is a face of the inbox, not a tab, so gating the
    // other two leaves the inbox alone on the bar.
    expect(tabLabels(tester), ['Messages']);
  });

  testWidgets('all features on keeps the three tabs', (tester) async {
    await pumpWithFlags(tester, const {});

    expect(tabLabels(tester), ['Messages', 'Calendar', 'Money']);
  });

  testWidgets('membersDirectory OFF drops the inbox face, not a tab',
      (tester) async {
    await pumpWithFlags(tester, const {'membersDirectory': false});

    // The bar is untouched...
    expect(tabLabels(tester), ['Messages', 'Calendar', 'Money']);
    await openAlertsTab(tester);
    // ...and the directory is simply not one of the inbox's faces.
    expect(find.byKey(const ValueKey('inbox-tab-members')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsOneWidget);
  });

  testWidgets(
      'with Calendar disabled the pending badge still lands on the inbox '
      'and its Alerts face still opens (#702)', (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([pendingForMe('e1'), pendingForMe('e2')]);
    await pumpWithFlags(tester, const {'calendarTab': false}, events: events);

    // The badge renders on the inbox destination, whatever else is gated.
    expect(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await openAlertsTab(tester);
    // The feed itself, with the two pending confirmations on it.
    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets(
      'everything gated off keeps the inbox — the bar stays, the alerts '
      'face goes (#702)', (tester) async {
    await pumpWithFlags(
      tester,
      const {'calendarTab': false, 'eventsTab': false, 'moneyTab': false},
    );

    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(tabLabels(tester), ['Messages']);
    expect(find.byTooltip('Events'), findsNothing);
    // The app boots on the Reserve hub (its branch is never gated).
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Reserve'),
    );
    expect(appBarTitle, findsOneWidget);
  });
}
