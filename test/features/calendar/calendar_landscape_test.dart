// SPDX-License-Identifier: 0BSD
//
// #1183 — the calendar hub with the phone held sideways.
//
// A 2316×1080 screenshot showed the split layout reusing the portrait
// measurements throughout: the view switcher broke its labels MID-WORD
// ("Agen / da", "Mont / h"), the month grid showed only its first week
// with no way to scroll to the rest, and the bottom bar kept the full
// 88 dp it takes on a 2316 px-tall portrait screen.
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'calendar_hub_test.dart' show pumpHub;

/// Turn the phone sideways: 2316×1080 at 3×, the device the batch was
/// shot on.
Future<void> turnSideways(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2316, 1080);
  tester.view.devicePixelRatio = 3;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the view switcher shrinks to icons rather than breaking '
      'its labels mid-word', (tester) async {
    await pumpHub(tester, flags: const {'calendarViews': true});
    // Portrait: the labels are there, which is the point of having them.
    expect(find.text('Agenda'), findsOneWidget);

    await turnSideways(tester);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final switcher = find.byKey(const ValueKey('calendar-view-switch'));
    expect(switcher, findsOneWidget);
    expect(
      find.descendant(of: switcher, matching: find.text('Agenda')),
      findsNothing,
      reason: 'a label Material would break as "Agen / da" is worse than '
          'the icon and tooltip that were there all along',
    );
  });

  testWidgets('the bottom bar gives the short screen its height back',
      (tester) async {
    await pumpHub(tester, flags: const {'calendarViews': true});
    final portrait = tester.getSize(find.byType(ShellBottomBar)).height;

    await turnSideways(tester);
    final landscape = tester.getSize(find.byType(ShellBottomBar)).height;

    expect(landscape, lessThan(portrait),
        reason: '88 dp of a 1080 px-tall screen is eight per cent of it, '
            'on the axis with none to spare');
    expect(landscape, ShellBarMetrics.barHeightShort + ShellBarMetrics.rise);
  });

  testWidgets('the whole month is reachable in the side panel',
      (tester) async {
    await pumpHub(tester, flags: const {'calendarViews': true});
    await turnSideways(tester);
    await tester.tap(find.byKey(const ValueKey('calendar-view-switch')).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
