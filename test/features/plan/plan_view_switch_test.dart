// SPDX-License-Identifier: 0BSD
//
// #209: the plan's list/canvas toggle cross-fades via AnimatedSwitcher —
// mid-transition both branch subtrees are in the tree; after settling
// only the target branch remains. Since #211 the toggle is the shared
// ViewToggle (segmented, both icons always present) — taps target the
// segment icons instead of the old flipping IconButton.
import 'package:deskilo/core/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart' show pumpPlan;

const _canvasKey = ValueKey('plan-canvas-view');
const _listKey = ValueKey('plan-list-view');

void main() {
  testWidgets(
      'toggling to list view cross-fades: both branches mid-transition, '
      'only the list after settling', (tester) async {
    await pumpPlan(tester);

    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byKey(_listKey), findsNothing);

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pump();
    // Halfway through the fade both children are mounted.
    await tester.pump(AppMotion.viewSwitch ~/ 2);
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byKey(_listKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(_canvasKey), findsNothing);
    expect(find.byKey(_listKey), findsOneWidget);

    // And back to the canvas.
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(_canvasKey), findsOneWidget);
    expect(find.byKey(_listKey), findsNothing);
  });
}
