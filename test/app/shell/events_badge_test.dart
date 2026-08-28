// SPDX-License-Identifier: 0BSD
//
// Where the pending-confirmation count lives (#230, moved again by
// #702). The feed left the bottom bar for an app-bar bell, and left the
// bell for the inbox's Alerts tab: the count now rides the inbox
// destination — beside the unread messages it always sat next to — and
// the Alerts tab carries its own. The eventsTab flag still hides the
// whole thing, one level in.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

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

Future<void> pumpApp(
  WidgetTester tester, {
  FakeEventRepository? events,
  Map<String, dynamic>? featureFlags,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: featureFlags == null
            ? null
            : FakeWorkspaceRepository.withWorkspace(featureFlags: featureFlags),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the pending count badges the inbox destination and its tab',
      (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([pendingForMe('e1'), pendingForMe('e2')]);
    await pumpApp(tester, events: events);

    // On the DESTINATION, so it is visible from every other tab — the
    // one job the bell did that a tab cannot.
    expect(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    // And on the face responsible for it, so the inbox does not make you
    // open all three to find the one with something in it.
    await openAlertsTab(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inbox-tab-alerts')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('no badge without pending confirmations', (tester) async {
    await pumpApp(tester);
    expect(find.byType(Badge), findsNothing);

    await openAlertsTab(tester);
    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('the Alerts tab shows the feed WITHOUT leaving the shell',
      (tester) async {
    await pumpApp(tester);

    await openAlertsTab(tester);

    // The bell pushed a root-level route that covered the bottom bar;
    // the tab does not. You can still reach anywhere else in one tap.
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
  });

  testWidgets('the Alerts tab is hidden when the events feature is disabled',
      (tester) async {
    await pumpApp(tester, featureFlags: const {'eventsTab': false});

    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    // The settings gear stays — only the feed is gated.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
