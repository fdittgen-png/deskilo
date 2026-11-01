// SPDX-License-Identifier: AGPL-3.0-or-later
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
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:deskilo/features/reservations/presentation/widgets/seat_legend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reserve_view.dart';
import '../../helpers/screens/reserve_hub.dart' show pumpHub;

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
    await tester.tap(find.byKey(const ValueKey('reserve-level-menu')));
    await tester.pumpAndSettle();
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

  // #3068 — the legend left the first screen. It is one tap away behind a
  // button in the view controls, opens in a sheet, and once a person has
  // opened it the inline copy stops taking room. The #1269 guarantee
  // survives where the legend now lives: every entry on one row.
  for (final size in const [Size(360, 800), Size(1192, 760)]) {
    testWidgets('the legend is one tap away and reads on one row at '
        '${size.width.round()} dp', (tester) async {
      await pumpHub(tester, size: size);
      final button = find.byKey(const ValueKey('reserve-legend-button'));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).shortestSide,
          greaterThanOrEqualTo(kMinInteractiveDimension),
          reason: 'a 48 dp target');
      await tester.tap(button);
      await tester.pumpAndSettle();

      final legend = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byKey(const ValueKey('reserve-legend')));
      expect(legend, findsOneWidget, reason: 'the same SeatLegend, in a sheet');
      final labels = find.descendant(of: legend, matching: find.byType(Text));
      expect(labels, findsAtLeast(5));
      final tops = {
        for (final e in labels.evaluate())
          tester.getRect(find.byWidget(e.widget)).top.round(),
      };
      expect(tops.length, 1,
          reason: 'the legend wrapped onto ${tops.length} rows');
      final box = tester.getRect(legend);
      for (final e in labels.evaluate()) {
        expect(tester.getRect(find.byWidget(e.widget)).right,
            lessThanOrEqualTo(box.right + 1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opened once, the inline legend no longer takes the first '
      'screen — and that is remembered on the device', (tester) async {
    final device = InMemoryHelpHintStore();
    await pumpHub(tester, size: const Size(1192, 760), helpHints: device);
    // A first visit still shows it where it was: nobody is asked to find a
    // button to learn what the colours mean.
    final inline = find.byKey(const ValueKey('reserve-legend'));
    expect(inline, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reserve-legend-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ModalBarrier).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(inline, findsNothing, reason: 'opened once: hidden from now on');
    expect(device.dismissed, contains('reserve.legend'));

    // The same device after a restart: still hidden, still one tap away.
    await tester.pumpWidget(const SizedBox());
    await pumpHub(tester, size: const Size(1192, 760), helpHints: device);
    expect(inline, findsNothing);
    expect(find.byKey(const ValueKey('reserve-legend-button')),
        findsOneWidget);
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
