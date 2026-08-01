// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app boots on the Reserve hub (the centre button's form is the
/// default screen); tests exercising the Plan tab switch to it first.
/// Scoped to the bar: the hub's view toggle also carries a 'Plan' label.
Future<void> switchToPlanTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ShellBottomBar),
      matching: find.text('Plan'),
    ),
  );
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
