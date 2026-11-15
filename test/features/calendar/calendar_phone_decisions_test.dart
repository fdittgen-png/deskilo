// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4055 — on a phone the calendar's own controls come first: with six
// decisions waiting, the view bar and the date are in the first view, the
// decisions are one row "Decisions (6)", and that row opens the Alerts view.
import 'package:deskilo/features/calendar/presentation/screens/calendar_hub_screen.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _features = {
  WorkspaceFeature.calendarTab,
  WorkspaceFeature.calendarHub,
  WorkspaceFeature.calendarViews,
  WorkspaceFeature.calendarValidations,
  WorkspaceFeature.eventsTab,
};

WorkspaceEvent _decision(int i) => WorkspaceEvent(
  id: 'e$i',
  workspaceId: 'ws-1',
  type: EventType.payment,
  action: EventAction.created,
  actorMemberId: 'member-2',
  subjectMemberId: 'member-2',
  payload: {'amount_cents': 1000 + i},
  status: EventStatus.pending,
  createdAt: DateTime.utc(2026, 11, 10, 9, i),
);

void main() {
  testWidgets('six decisions are one row; the view bar and the date are in '
      'the first view; the row opens Alerts', (tester) async {
    const size = Size(390, 844);
    await pumpApp(
      tester,
      const CalendarHubScreen(),
      size: size,
      overrides: [
        ...standardTestOverrides(),
        enabledFeaturesSyncProvider.overrideWithValue(_features),
        myPendingEventsProvider.overrideWith(
          (ref) async => [for (var i = 0; i < 6; i++) _decision(i)],
        ),
      ],
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('calendar-decisions-entry'));
    expect(entry, findsOneWidget);
    expect(
      find.descendant(of: entry, matching: find.text('Decisions (6)')),
      findsOneWidget,
    );
    for (final key in ['calendar-view-switch', 'calendar-date-button']) {
      final control = find.byKey(ValueKey(key));
      expect(control, findsWidgets, reason: key);
      expect(
        tester.getRect(control.first).bottom,
        lessThanOrEqualTo(size.height),
        reason: '$key is in the first view',
      );
    }

    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsOneWidget);
  });

  testWidgets('with nothing to decide there is no row', (tester) async {
    await pumpApp(
      tester,
      const CalendarHubScreen(),
      size: const Size(390, 844),
      overrides: [
        ...standardTestOverrides(),
        enabledFeaturesSyncProvider.overrideWithValue(_features),
        myPendingEventsProvider.overrideWith((ref) async => const []),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-decisions-entry')),
      findsNothing,
    );
  });
}
