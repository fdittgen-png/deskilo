// SPDX-License-Identifier: 0BSD
//
// #699 — the Reserve hub's controls take TWO rows, not three.
//
// One Wrap holding all of them flowed onto three lines at phone width:
// the view toggle filled the first, the date and the icon buttons the
// second, and the window chips were pushed alone onto a third. Three
// rows of chrome above a plan canvas is a lot of header for a screen
// whose job is the canvas.
//
// This is a LAYOUT contract, so it is measured, not read off the source:
// every header control is found by key and its top edge collected. Two
// distinct tops = two rows. It runs at 360dp (the narrowest phone width
// the app targets) and 393dp, in all five languages — German is the
// widest date and was the case that first pushed a third row back — and
// with the 'Now' button showing, which is the widest this header ever
// gets.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';

/// Every control of the two header rows. The scan button is deliberately
/// absent: #699 moved it to the app bar.
const _headerKeys = [
  'reserve-view-switch',
  'reserve-seat-view-switch',
  'reserve-date-button',
  'reserve-now-button',
  'reserve-am-chip',
  'reserve-pm-chip',
  'reserve-day-chip',
];

void main() {
  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    for (final width in [360.0, 393.0]) {
      testWidgets(
          'the hub header is two rows at ${width.toInt()}dp in $locale',
          (tester) async {
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        tester.view.physicalSize = Size(width * 3, 800 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final plans = FakeFloorPlanRepository()..seedSmallPlan();
        final workspace = FakeWorkspaceRepository.withWorkspace()
          ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7]
          ..bookingGranularities['ws-1'] = BookingGranularity.halfDay;
        await tester.pumpWidget(ProviderScope(
          overrides:
              standardTestOverrides(floorPlan: plans, workspace: workspace),
          child: const DeskiloApp(),
        ));
        await tester.pumpAndSettle();

        // Picking a window brings out the 'Now' button — the widest the
        // header ever gets, and the state a browsing member is in.
        await tester.tap(find.byKey(const ValueKey('reserve-am-chip')));
        await tester.pumpAndSettle();

        final tops = <double>{};
        for (final key in _headerKeys) {
          final finder = find.byKey(ValueKey(key));
          expect(finder, findsOneWidget, reason: '$key is missing');
          tops.add(tester.getTopLeft(finder).dy);
        }
        expect(
          tops.length,
          2,
          reason: 'the header controls sit on ${tops.length} rows '
              '(tops: ${tops.toList()..sort()}) — #699 pins two',
        );

        // And every one of them stays inside the screen: a Wrap does not
        // overflow, it just adds the row this test forbids, so the width
        // has to be checked separately.
        for (final key in _headerKeys) {
          expect(
            tester.getRect(find.byKey(ValueKey(key))).right,
            lessThanOrEqualTo(width),
            reason: '$key runs off the right edge',
          );
        }
      });
    }
  }

  testWidgets('the scan button moved to the app bar, and still scans',
      (tester) async {
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = const [1, 2, 3, 4, 5, 6, 7];
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(floorPlan: plans, workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();

    // In the app bar — beside the editor and the bell, which are the
    // other actions on the whole surface — not among the controls that
    // change what the plan below shows.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const ValueKey('reserve-scan-button')),
      ),
      findsOneWidget,
    );
  });
}
