// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puts the plan canvas on screen (#687).
///
/// It used to tap the Plan TAB. There is no Plan tab any more — the hub
/// is the only map surface, and the app already boots onto it with the
/// plan view selected. So this settles and returns.
///
/// The name is kept, and that is deliberate: seventeen test files call
/// it to mean "show me the plan", which is still exactly what it does.
/// Renaming it would have churned every one of them to say the same
/// thing a different way, and the churn is where a real assertion gets
/// lost.
///
/// It taps the hub's plan segment when something else is showing, so a
/// test that switched to Day or Week can still come back.
Future<void> switchToPlanTab(WidgetTester tester) async {
  final planSegment = find.byKey(const ValueKey('reserve-plan-view'));
  if (planSegment.evaluate().isNotEmpty) {
    await tester.tap(planSegment);
  }
  await tester.pumpAndSettle();
}

/// Taps a bottom-bar destination BY ICON, scoped to the bar. Icons repeat
/// across surfaces (calendar_month is a nav destination AND a date-picker
/// button) and an unscoped `.first` taps the occluded copy — after which
/// the warnIfMissed warning quietly hides that a surface was never
/// visited. Icon-based (not label-based) so locale-varying tests can use
/// it: the labels are translated, the icons are not.
Future<void> tapNavIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ShellBottomBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps an app-bar action by icon — same scoping rationale as
/// [tapNavIcon].
Future<void> tapAppBarIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the inbox's ALERTS face (#702) — where the app-bar bell used to
/// lead before the events feed became a tab of the inbox.
///
/// Kept as a helper for the same reason as [switchToPlanTab]: nine test
/// files mean "show me the feed", and that is still exactly what this
/// does. It works whether or not the inbox is already the showing
/// destination.
Future<void> openAlertsTab(WidgetTester tester) async {
  const tab = ValueKey('inbox-tab-alerts');
  if (find.byKey(tab).evaluate().isEmpty) {
    await tapNavIcon(tester, Icons.forum_outlined);
  }
  await tester.tap(find.byKey(tab));
  await tester.pumpAndSettle();
}

/// Opens the member directory (#707) — a bottom-bar destination again,
/// after a brief life as the inbox's third face in #702.
Future<void> openMembersTab(WidgetTester tester) =>
    tapNavIcon(tester, Icons.people_outline);
