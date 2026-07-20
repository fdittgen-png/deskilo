// SPDX-License-Identifier: MIT
import 'package:deskilo/core/ui/canvas_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _scale(TransformationController c) => c.value.getMaxScaleOnAxis();

Future<TransformationController> _pump(WidgetTester tester) async {
  final controller = TransformationController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: CanvasControls(
            controller: controller,
            contentSize: const Size(1680, 1680),
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('zoom in / out / reset drive the shared transform',
      (tester) async {
    final controller = await _pump(tester);
    expect(_scale(controller), 1.0);

    await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
    await tester.pump();
    expect(_scale(controller), greaterThan(1.0));

    final zoomed = _scale(controller);
    await tester.tap(find.byKey(const ValueKey('canvas-zoom-out')));
    await tester.pump();
    expect(_scale(controller), lessThan(zoomed));

    // Zoom in twice, then reset returns to identity.
    await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('canvas-zoom-reset')));
    await tester.pump();
    expect(_scale(controller), 1.0);
    expect(controller.value.getTranslation().x, 0);
    expect(controller.value.getTranslation().y, 0);
  });

  testWidgets('zoom-in stops at maxScale and disables the button',
      (tester) async {
    final controller = await _pump(tester); // maxScale defaults to 3
    for (var i = 0; i < 6; i++) {
      final inButton = find.byKey(const ValueKey('canvas-zoom-in'));
      if (tester.widget<InkWell>(inButton).onTap == null) break;
      await tester.tap(inButton);
      await tester.pump();
    }
    expect(_scale(controller), closeTo(3.0, 1e-6));
    // At the ceiling the in-button is disabled (no onTap).
    expect(
      tester
          .widget<InkWell>(find.byKey(const ValueKey('canvas-zoom-in')))
          .onTap,
      isNull,
    );
  });
}
