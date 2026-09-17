// SPDX-License-Identifier: 0BSD
//
// #1306 S3 — every badge opens the content it counts, and a workspace
// switch never leaves the shell on a destination the new workspace hides.
//
// The pending-decision count has four places it can show: the bell, the
// Calendar destination (when the bell is off and the calendar carries the
// decisions), the web drawer, and the Reserve button while the bars are
// swiped away. With the bell off, the last two used to stay silent — a
// decision a full-screen or web user could not see.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/events/events_screen_test.dart' show event;
import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

const _bellOff = {
  'eventsTab': false,
  'calendarTab': true,
  'calendarHub': true,
  'calendarValidations': true,
};

FakeEventRepository _pending() => FakeEventRepository()
  ..events.add(event(
    actor: 'member-2',
    subject: 'member-1',
    status: EventStatus.pending,
  ));

void main() {
  testWidgets('bell off, bars swiped away: the Reserve button carries the '
      'count the Calendar badge showed', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        events: _pending(),
        workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: _bellOff),
        shellBarHidden: InMemoryShellFlagStore(true),
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(ShellCenterButton), matching: find.byType(Badge)),
      findsOneWidget,
    );
  });

  testWidgets('bell off, on the web: the drawer badges Calendar, the entry '
      'that opens the decisions', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...standardTestOverrides(
          events: _pending(),
          workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: _bellOff),
        ),
        webShellProvider.overrideWithValue(true),
      ],
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drawer-events')), findsNothing);
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('drawer-tab-1')), matching: find.byType(Badge)),
      findsOneWidget,
    );
    expect(find.byType(ShellDrawer), findsOneWidget);
  });

  testWidgets('a workspace switch that hides the current destination lands '
      'on Messages, never on an empty branch', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: const {'calendarTab': true});
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Calendar')),
        findsOneWidget);

    // The other workspace has no calendar.
    workspace.workspaces[0] = workspace.workspaces[0]
        .copyWith(featureFlags: const {'calendarTab': false});
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .invalidate(myWorkspacesProvider);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Messages')),
        findsOneWidget);
    expect(find.text('Calendar'), findsNothing,
        reason: 'the destination went with its feature');
  });
}
