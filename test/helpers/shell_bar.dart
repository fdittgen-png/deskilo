// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3788 — a control of the shell's top bar is a button while the bar holds
// it, and an entry of the bar's overflow menu where the page's name needs
// the room. A test taps it where it is on screen, never by a width.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Taps the bar's control [key]: its button when the bar shows it, else its
/// entry behind the overflow button. Does not pump after the tap.
Future<void> tapShellBarControl(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key)).hitTestable();
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button.first);
    return;
  }
  await tester.tap(find.byKey(const ValueKey('shell-overflow-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('shell-overflow-$key')));
}
