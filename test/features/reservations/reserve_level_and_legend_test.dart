// SPDX-License-Identifier: 0BSD
//
// #1269 — two things the Reserve hub's header got wrong, from a field
// report with screenshots.
//
//   * "The level is changing always to the first." Plan, Day and Week
//     each held their OWN `_levelId` State field. Switching view
//     disposed the widget that knew which floor you were on and built
//     one that started at null, which resolves to `levels.first`. The
//     browsed level is now one keepAlive provider the three views read
//     and write ([BrowsedLevel]).
//   * "the blocked is on the 2nd row. Make sure that all explanation
//     are on the same row." The legend wrapped, and one entry alone on
//     a second line reads as a heading for what is under it.
import 'package:deskilo/features/reservations/presentation/widgets/seat_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;
import '../../helpers/reserve_view.dart';

/// The hub's plan-view level rail (a column of 48dp pills).
Finder _planLevel(String id) =>
    find.byKey(ValueKey('reserve-level-$id'));

/// The Day and Week views use the chip row, which carries no keys —
/// the chip's own name is the finder.
Finder _chip(String name) => find.widgetWithText(ChoiceChip, name);

bool _chipSelected(WidgetTester tester, Finder f) =>
    tester.widget<ChoiceChip>(f).selected;

/// Chooses Day / Plan / Week / Month from the View menu (#1301 S2).
Future<void> _switchTo(WidgetTester tester, String view) async {
  await pickReserveView(tester, view.toLowerCase());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the browsed level survives every view switch',
      (tester) async {
    await pumpHub(tester, twoLevels: true);

    // Plan opens on the first floor, as it always did.
    await tester.tap(_planLevel('level-9'));
    await tester.pumpAndSettle();

    // Day: the same floor, not "Ground floor" again.
    await _switchTo(tester, 'Day');
    expect(_chipSelected(tester, _chip('First floor')), isTrue,
        reason: 'the Day view built its own level state and started at '
            'levels.first');
    expect(_chipSelected(tester, _chip('Ground floor')), isFalse);

    // Week, and back to Plan: still the first floor.
    await _switchTo(tester, 'Week');
    expect(_chipSelected(tester, _chip('First floor')), isTrue);

    await _switchTo(tester, 'Plan');
    await _switchTo(tester, 'Day');
    expect(_chipSelected(tester, _chip('First floor')), isTrue,
        reason: 'a round trip through Plan must not reset it either');
  });

  testWidgets('a view that cannot honour "all levels" leaves it alone',
      (tester) async {
    await pumpHub(tester, twoLevels: true);
    await _switchTo(tester, 'Day');
    await tester.tap(_chip('All levels'));
    await tester.pumpAndSettle();
    expect(_chipSelected(tester, _chip('All levels')), isTrue);

    // The plan paints ONE floor; it resolves the sentinel to a level to
    // draw, and must not write that resolution back.
    await _switchTo(tester, 'Plan');
    await _switchTo(tester, 'Day');
    expect(_chipSelected(tester, _chip('All levels')), isTrue,
        reason: 'the plan overwrote a value it merely could not show');
  });

  testWidgets('every legend entry sits on the same row', (tester) async {
    // The width the report was shot at: 360 dp is where the five plan
    // states needed 361 dp and "Blocked" fell to a second line.
    await pumpHub(tester, size: const Size(360, 800));
    final legend = find.byKey(const ValueKey('reserve-legend'));
    expect(legend, findsOneWidget);

    final labels = find.descendant(of: legend, matching: find.byType(Text));
    expect(labels, findsAtLeast(5));
    final tops = {
      for (final e in labels.evaluate())
        tester.getRect(find.byWidget(e.widget)).top.round(),
    };
    expect(tops.length, 1,
        reason: 'the legend wrapped onto ${tops.length} rows — "Blocked" '
            'alone under the others reads as a heading, not as the fifth '
            'of five equals');
    // And it stays inside the screen rather than running off it.
    final box = tester.getRect(legend);
    for (final e in labels.evaluate()) {
      expect(tester.getRect(find.byWidget(e.widget)).right,
          lessThanOrEqualTo(box.right + 1));
    }
  });

  testWidgets('a reader who asked for larger text gets it, wrapped',
      (tester) async {
    // Scaling the row down would hand them back exactly the size they
    // said was too small, so above 1.15 the legend wraps instead — two
    // honest lines beat one unreadable one.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<double> freeHeight(double scale) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const MaterialApp(home: Scaffold(body: SeatLegend())),
      ));
      await tester.pumpAndSettle();
      return tester.getSize(find.text('Free')).height;
    }

    final plain = await freeHeight(1);
    final large = await freeHeight(1.6);
    expect(find.byType(FittedBox), findsNothing);
    final tops = {
      for (final e in find.byType(Text).evaluate())
        tester.getRect(find.byWidget(e.widget)).top.round(),
    };
    expect(tops.length, greaterThan(1),
        reason: 'enlarged, the legend should take the second line');
    expect(large, greaterThan(plain * 1.4),
        reason: 'the scale-down gave the enlarged text back at $large dp '
            'against $plain dp unscaled — which is the setting ignored');
  });
}
