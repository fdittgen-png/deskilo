// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/features/workspace/presentation/widgets/conversation_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// #3603 — a destination by icon: on the bottom bar where there is one, in
/// the desk's navigation (sidebar or rail) from the expanded window class,
/// where the bar is gone.
Finder navDestination(IconData icon) {
  final bar = find.descendant(
    of: find.byType(ShellBottomBar),
    matching: find.byIcon(icon),
  );
  if (bar.evaluate().isNotEmpty) return bar;
  final desk = find.descendant(
    of: find.byKey(const ValueKey('desk-navigation')),
    matching: find.byIcon(icon),
  );
  return desk.evaluate().isEmpty ? desk : desk.first;
}

/// #3603 — the page's own scrollable: inside the desk's page area where the
/// desk is drawn (its navigation scrolls too), else the first on screen.
Finder pageScrollable() {
  final page = find.byKey(const ValueKey('desk-page'));
  return page.evaluate().isEmpty
      ? find.byType(Scrollable).first
      : find.descendant(of: page, matching: find.byType(Scrollable)).first;
}

/// Opens the Reserve hub: the bar's raised button, or the desk's entry
/// (#3603 — the desk has no raised button).
Future<void> openReserveHub(WidgetTester tester) async {
  final center = find.byType(ShellCenterButton);
  if (center.evaluate().isNotEmpty) {
    await tester.tap(center);
  } else {
    final rail = find.byKey(const ValueKey('rail-drawer-reserve'));
    await tester.tap(
      rail.evaluate().isNotEmpty
          ? rail
          : find.byKey(const ValueKey('drawer-reserve')),
    );
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
  await tester.tap(navDestination(icon));
  await tester.pumpAndSettle();
}

/// Taps an app-bar action by icon — same scoping rationale as
/// [tapNavIcon]. An action the bar moved behind its overflow (#3788) is
/// tapped there, under the same icon.
Future<void> tapAppBarIcon(WidgetTester tester, IconData icon) async {
  final onBar = find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(icon),
  );
  if (onBar.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('shell-overflow-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(icon).last);
  } else {
    await tester.tap(onBar);
  }
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
    final inbox = navDestination(Icons.forum_outlined);
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

/// Opens one workspace conversation through [showConversationThread], the
/// entry point every surface uses (#702): a member sheet, the directory,
/// an event row, a blocked booking. Discussions are listed in the Me
/// messenger now; the old workspace conversation list is gone (#2383), so
/// tests of the thread open it the way the app does — by id.
Future<void> openWorkspaceConversation(
  WidgetTester tester,
  String conversationId,
) async {
  // Any consumer under the router's navigator: its context reaches the
  // router and the sheets, and it is a WidgetRef.
  final element = tester.element(
    find
        .descendant(
          of: find.byType(Navigator).first,
          matching: find.byElementPredicate((e) => e is WidgetRef),
        )
        .first,
  );
  unawaited(showConversationThread(
    element,
    element as WidgetRef,
    conversationId: conversationId,
  ));
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
