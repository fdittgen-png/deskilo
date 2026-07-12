// SPDX-License-Identifier: MIT
//
// #209: the plan's list/canvas toggle cross-fades via AnimatedSwitcher —
// mid-transition both branch subtrees are in the tree; after settling
// only the target branch remains.
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

    await tester.tap(find.byIcon(Icons.list));
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
