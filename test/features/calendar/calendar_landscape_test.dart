// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1183 — the calendar hub with the phone held sideways.
//
// A 2316×1080 screenshot showed the split layout reusing the portrait
// measurements throughout: the view switcher broke its labels MID-WORD
// ("Agen / da", "Mont / h"), the month grid showed only its first week
// with no way to scroll to the rest, and the bottom bar kept the full
// 88 dp it takes on a 2316 px-tall portrait screen.
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart' show kTestNow;
import 'calendar_hub_test.dart' show pumpHub;

/// Turn the phone sideways: 2316×1080 at 3×, the device the batch was
/// shot on.
Future<void> turnSideways(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2316, 1080);
  tester.view.devicePixelRatio = 3;
  await tester.pumpAndSettle();
}

/// The Month segment of the view switcher — the thing a finger lands on,
/// not the switcher as a whole.
///
/// Tapping the switcher's own centre lands between segments; worse, on
/// this 360 dp-tall screen the whole bar starts below the fold of the
/// side panel, so the offset is outside the viewport entirely.
final _monthSegment = find.descendant(
  of: find.byKey(const ValueKey('calendar-view-switch')),
  matching: find.byIcon(Icons.calendar_month_outlined),
);

/// Scroll [target] into the side panel's viewport, then tap it.
///
/// Every tap in this file goes through here. A control a member has to
/// scroll to is reachable; a control the test taps at a coordinate the
/// panel has clipped away is not, and with
/// `hitTestWarningShouldBeFatal` the difference is a failure rather than
/// a line of console output nobody reads.
Future<void> scrollAndTap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  // #1446 — a tap that hits nothing must NOT be silent.
  //
  // Every interaction below used to print "derived an Offset that would
  // not hit test on the specified widget" in CI and pass anyway: the
  // pointer went down on empty canvas, no handler ran, and the test
  // then asserted only that no exception had been thrown — which is
  // exactly what a tap on nothing produces. A test whose action never
  // happened is not weaker evidence than a real one, it is no evidence
  // at all, and it is worse than having no test because it reports the
  // journey as covered.
  //
  // Making the warning fatal is what ties the assertions below to the
  // action they claim to measure.
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets('the view switcher shrinks to icons rather than breaking '
      'its labels mid-word', (tester) async {
    await pumpHub(tester, flags: const {'calendarViews': true});
    // Portrait: the labels are there, which is the point of having them.
    expect(find.text('Agenda'), findsOneWidget);

    await turnSideways(tester);
    await scrollAndTap(tester, _monthSegment);

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

  testWidgets('the whole month is reachable in the side panel: the last '
      'week can be selected and the feed follows', (tester) async {
    await pumpHub(tester, flags: const {'calendarViews': true});
    await turnSideways(tester);

    // 1 — the view is CHOSEN, on the segment that carries it.
    await scrollAndTap(tester, _monthSegment);
    expect(find.byKey(const ValueKey('calendar-month-grid')), findsOneWidget,
        reason: 'the Month segment selected the month view; the old test '
            'tapped the switcher\'s centre — between two segments, and '
            'below the fold besides — and asserted only that nothing '
            'threw, which a tap on empty canvas also satisfies');

    // The month opens on today, and today carries the fixture's rows.
    final today = find.byKey(const ValueKey('calendar-item-r1'));
    expect(today, findsOneWidget);

    // 2 — a day in the LAST week of the month, which is the part the
    // sideways panel used to clip away with no way to scroll to it.
    final lastWeekday = DateTime(kTestNow.year, kTestNow.month,
        DateUtils.getDaysInMonth(kTestNow.year, kTestNow.month) - 2);
    final cell = find.byKey(CalendarMonthGrid.cellKey(lastWeekday));
    expect(cell, findsOneWidget,
        reason: 'the grid draws every day of the month, not the first row');
    await scrollAndTap(tester, cell);

    // 3 — and the selection reached the feed, which is the outcome the
    // member came for. `ensureVisible` alone would prove the cell is
    // paintable; only the feed proves the day was chosen.
    expect(today, findsNothing,
        reason: 'the feed still showing today\'s reservation would mean the '
            'tap landed somewhere that changed nothing');
    expect(find.text('Nothing on this day.'), findsOneWidget,
        reason: 'the feed answers for the day the member picked');
    expect(tester.takeException(), isNull);
  });
}
