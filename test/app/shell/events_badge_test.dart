// SPDX-License-Identifier: 0BSD
//
// The app-bar events bell (#230): the events feed left the bottom bar, so
// the pending-confirmation badge now decorates the bell beside the
// settings gear, tapping the bell pushes the feed over the shell, and the
// eventsTab feature flag hides the bell entirely.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';

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
  testWidgets('the app-bar bell shows a badge with my pending count',
      (tester) async {
    final events = FakeEventRepository()
      ..events.addAll([pendingForMe('e1'), pendingForMe('e2')]);
    await pumpApp(tester, events: events);

    // The count decorates the bell itself, not a neighbouring action.
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.byType(Badge), findsWidgets);
  });

  testWidgets('no badge without pending confirmations', (tester) async {
    await pumpApp(tester);

    expect(find.byTooltip('Events'), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('tapping the bell pushes the events feed over the shell',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    // Root-level route like /settings: the feed covers the bottom bar and
    // brings its own app bar.
    expect(find.byType(ShellBottomBar), findsNothing);
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Events'),
    );
    expect(appBarTitle, findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
  });

  testWidgets('the bell is hidden when the events feature is disabled',
      (tester) async {
    await pumpApp(tester, featureFlags: const {'eventsTab': false});

    expect(find.byTooltip('Events'), findsNothing);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    // The settings gear stays — only the bell is gated.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
