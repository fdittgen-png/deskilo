// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4056 — at the desk, Agenda and Alerts are views of the desk's own choice:
// the phone's view bar is not drawn under it, so the page has one view
// control; the alerts' count stands on the desk's Alerts; the two choices
// are labelled for what they choose; the top bar names the page on every
// view.
import 'package:deskilo/app/shell/desk_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/desk_calendar.dart';

final _desk = find.byKey(const ValueKey('desk-mode'));
final _phoneBar = find.byKey(const ValueKey('calendar-view-switch'));

void main() {
  for (final query in ['?mode=agenda', '?view=alerts', '?mode=alerts']) {
    testWidgets('$query: one view control, the desk\'s', (tester) async {
      await pumpDeskCalendar(tester, query: query);
      expect(_desk, findsOneWidget);
      expect(_phoneBar, findsNothing, reason: 'no second selector');
      expect(
        find.descendant(
          of: find.byType(DeskBreadcrumb),
          matching: find.text('Calendar'),
        ),
        findsOneWidget,
        reason: 'the top bar names the page',
      );
    });
  }

  testWidgets('Alerts is the desk\'s own view, its count on it', (
    tester,
  ) async {
    await pumpDeskCalendar(tester, query: '?mode=agenda');
    final alerts = find.descendant(of: _desk, matching: find.text('Alerts'));
    expect(alerts, findsOneWidget);
    expect(
      find.descendant(
        of: _desk,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key == const ValueKey('calendar-alerts-count') ||
              w.key == const ValueKey('calendar-alerts-unknown'),
        ),
      ),
      findsOneWidget,
      reason: 'how many are new, on the desk\'s choice',
    );
    await tester.tap(alerts);
    await tester.pumpAndSettle();
    expect(locationOf(tester), contains('mode=alerts'));
    expect(find.byKey(const ValueKey('calendar-alerts-view')), findsOneWidget);
    expect(_phoneBar, findsNothing);
  });

  testWidgets('the two choices say what they choose', (tester) async {
    await pumpDeskCalendar(tester, query: '?view=week');
    expect(find.text('Range'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });
}
