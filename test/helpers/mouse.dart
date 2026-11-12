// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 — driving a screen with a mouse alone: connect one, hover, click
// with the secondary button.
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Connects a mouse for the rest of the test (removed on tear-down) and
/// rests it in the top-left corner, over nothing in particular.
Future<TestGesture> connectMouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pumpAndSettle();
  return mouse;
}

/// Moves [mouse] over the centre of [finder].
Future<void> hoverOver(
  WidgetTester tester,
  TestGesture mouse,
  Finder finder,
) async {
  await mouse.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
}

/// A right click on the centre of [finder].
Future<void> rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(
    finder,
    buttons: kSecondaryButton,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
}

/// A left click with the mouse on the centre of [finder].
Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}
