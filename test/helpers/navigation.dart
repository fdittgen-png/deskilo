// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'workspace_chat_list.dart';
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
  // The face carries the messenger door and the requests row above the
  // feed; the default 800x600 surface no longer holds a whole feed under
  // them, so the helper asks for a taller one (restored after the test).
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (size.height < 900) {
    tester.view.physicalSize = Size(size.width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  // The alerts live in the calendar's Alerts view (the Messages destination
  // is gone with the calendar hub on); a workspace without the hub still has
  // the inbox destination.
  if (find.byKey(const ValueKey('inbox-messenger-door')).evaluate().isEmpty) {
    final inbox = find.descendant(
      of: find.byType(ShellBottomBar),
      matching: find.byIcon(Icons.forum_outlined),
    );
    if (inbox.evaluate().isNotEmpty) {
      await tester.tap(inbox);
    } else {
      await tapNavIcon(tester, Icons.calendar_month_outlined);
      final alerts = find.descendant(
        of: find.byKey(const ValueKey('calendar-view-switch')),
        matching: find.byIcon(Icons.notifications_outlined),
      );
      await tester.tap(alerts.first);
    }
  }
  await tester.pumpAndSettle();
}

/// Opens the member directory (#707) — a bottom-bar destination again,
/// after a brief life as the inbox's third face in #702.
Future<void> openMembersTab(WidgetTester tester) =>
    tapNavIcon(tester, Icons.people_outline);

/// Taps an invoicing tool by its key: the tools live in the hub's labelled
/// menu, so the menu is opened first when the item is not on screen.
Future<void> tapInvoicingTool(WidgetTester tester, String key) async {
  final item = find.byKey(ValueKey(key));
  if (item.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('invoicing-tools')));
    await tester.pumpAndSettle();
  }
  await tester.tap(item);
  await tester.pumpAndSettle();
}

/// Opens the workspace's conversation list (a test-only harness; the app
/// has no such screen — #2210). Discussions live in the Me messenger now and the workspace
/// inbox only carries alerts, so tests of the conversation machinery reach
/// the list directly.
Future<void> openWorkspaceChats(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const WorkspaceChatList()),
  );
  await tester.pumpAndSettle();
}
Future<void> openMoneyWorkspaceTools(WidgetTester tester) async {
  final tools = find.byKey(const ValueKey('money-workspace-tools'));
  final body = find.byKey(const ValueKey('money-face-body-invoices'));
  if (body.evaluate().isNotEmpty && find.byKey(const ValueKey('invoices-button')).evaluate().isEmpty) {
    await tester.scrollUntilVisible(tools, 160, scrollable: find.descendant(of: body, matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(tools);
    await tester.pumpAndSettle();
    await tester.tap(tools);
    await tester.pumpAndSettle();
  }
}
