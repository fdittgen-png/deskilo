// SPDX-License-Identifier: AGPL-3.0-or-later
// #2276 — controls remain reachable at large text without taking the feed's
// entire viewport; ordinary controls leave all remaining space for activity.
import 'package:deskilo/core/ui/controls_feed_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBody(WidgetTester tester, List<Widget> controls) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 360,
              height: 600,
              child: ControlsFeedBody(
                controls: controls,
                feed: const ColoredBox(
                  key: ValueKey('feed'),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('short controls leave all remaining height for activity', (
    tester,
  ) async {
    await pumpBody(tester, [const SizedBox(height: 48)]);
    expect(tester.getSize(find.byKey(const ValueKey('feed'))).height, 552);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tall controls scroll while the activity feed stays visible', (
    tester,
  ) async {
    var reached = false;
    await pumpBody(tester, [
      const SizedBox(height: 800),
      TextButton(
        onPressed: () => reached = true,
        child: const Text('Last control'),
      ),
    ]);
    expect(tester.getSize(find.byKey(const ValueKey('feed'))).height, 200);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last control'));
    expect(reached, isTrue);
    expect(tester.takeException(), isNull);
  });
}
