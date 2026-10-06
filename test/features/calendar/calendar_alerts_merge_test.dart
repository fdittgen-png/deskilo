// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: the calendar is where alerts and events live. With the calendar
// hub on there is no Alerts destination; the Calendar carries the pending
// count, offers an Alerts view beside Agenda · Week · Month, the bell and the
// /events path land on that view, and the feed in it is the same one the
// inbox showed (decisions on top, filters below).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

WorkspaceEvent _pending(String id) => WorkspaceEvent(
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

Future<void> _pump(WidgetTester tester, {Map<String, dynamic>? flags}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final events = FakeEventRepository()
    ..events.addAll([_pending('e1'), _pending('e2')]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: flags == null
            ? null
            : FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no Alerts destination: the Calendar carries the count', (
    tester,
  ) async {
    await _pump(tester);
    final bar = find.byType(ShellBottomBar);
    expect(
      find.descendant(of: bar, matching: find.text('Alerts')),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byIcon(Icons.forum_outlined)),
      findsNothing,
    );
    expect(find.descendant(of: bar, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('the Alerts view sits beside Agenda, Week and Month', (
    tester,
  ) async {
    await _pump(tester);
    await tapNavIcon(tester, Icons.calendar_month_outlined);
    final switcher = find.byKey(const ValueKey('calendar-view-switch'));
    expect(
      find.descendant(
        of: switcher,
        matching: find.byIcon(Icons.notifications_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsNothing);

    // The icon wears the pending-count badge: the segment is tapped by its
    // tooltip, which is the whole segment.
    await tester.tap(
      find.descendant(of: switcher, matching: find.byTooltip('Alerts')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-messenger-door')), findsOneWidget);
    // Back to a date view leaves the alerts.
    await tester.tap(
      find.descendant(
        of: switcher,
        matching: find.byIcon(Icons.view_agenda_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsNothing);
  });

  testWidgets('the bell lands on the calendar\'s Alerts view', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('shell-events-bell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('without the calendar hub the inbox destination remains', (
    tester,
  ) async {
    await _pump(tester, flags: const {'calendarHub': false});
    expect(
      find.descendant(
        of: find.byType(ShellBottomBar),
        matching: find.byIcon(Icons.forum_outlined),
      ),
      findsOneWidget,
    );
  });
}
