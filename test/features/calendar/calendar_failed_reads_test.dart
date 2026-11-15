// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4017 — a failed read on the calendar is said, never shown as nothing:
// the approvals' failure takes their place with Retry, the Alerts mark has
// no number and is named unknown, and the feed's failure offers Retry too.
import 'package:deskilo/app/shell/shell_destinations.dart';
import 'package:deskilo/features/calendar/presentation/calendar_view.dart';
import 'package:deskilo/features/calendar/presentation/screens/calendar_hub_screen.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_view_bar.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/presentation/widgets/calendar_decisions.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

const _onCalendar = {
  WorkspaceFeature.calendarTab,
  WorkspaceFeature.calendarValidations,
};

void main() {
  test('the decisions live on the calendar with these features', () {
    expect(decisionSignalOnCalendar(_onCalendar), isTrue);
  });

  testWidgets('the approvals that could not be read say so with Retry, and '
      'Retry reads them again', (tester) async {
    var reads = 0;
    await pumpApp(
      tester,
      const Scaffold(body: CalendarDecisions()),
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue(_onCalendar),
        myPendingEventsProvider.overrideWith((ref) async {
          reads++;
          if (reads == 1) throw StateError('the server did not answer');
          return const [];
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-failure')), findsOneWidget);
    expect(find.text(_en.readStateFailed), findsOneWidget);

    await tester.tap(find.text(_en.commonRetry));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.byKey(const ValueKey('read-failure')), findsNothing);
  });

  testWidgets('a count that could not be read is a mark without a number, '
      'named unknown', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => CalendarViewBar(
            view: CalendarView.agenda,
            onView: (_) {},
            onToday: () {},
            alertsAvailable: true,
            onAlerts: () {},
            alertsCount: pendingAlertCount(ref),
          ),
        ),
      ),
      size: const Size(800, 400),
      overrides: [
        myPendingEventCountProvider.overrideWith(
          (ref) async => throw StateError('the server did not answer'),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('calendar-alerts-unknown')),
      findsOneWidget,
    );
    expect(find.text('0'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(_en.calendarAlertsCountUnknown)),
      findsOneWidget,
    );
  });

  testWidgets('the feed that could not be read says so with Retry', (
    tester,
  ) async {
    var reads = 0;
    await pumpApp(
      tester,
      const CalendarHubScreen(),
      size: const Size(800, 1200),
      overrides: [
        ...standardTestOverrides(),
        calendarItemsProvider.overrideWith((ref, query) async {
          reads++;
          throw StateError('the server did not answer');
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('read-failure')), findsWidgets);
    final before = reads;
    await tester.tap(find.text(_en.commonRetry).last);
    await tester.pumpAndSettle();
    expect(reads, greaterThan(before), reason: 'Retry reads the feed again');
  });
}
