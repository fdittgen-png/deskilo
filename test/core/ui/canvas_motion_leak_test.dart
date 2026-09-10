// SPDX-License-Identifier: 0BSD
// #1090 — a CurvedAnimation registers a status listener on its parent in
// its constructor and removes it only in dispose(). One built per frame
// (the glide listener) or per rebuild (FadeInOnChange.build) therefore
// leaves a permanent listener behind every single time.
import 'package:deskilo/core/motion/motion.dart';
import 'package:deskilo/core/ui/canvas_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  LeakTesting.enable();
  LeakTracking.warnForUnsupportedPlatforms = false;

  testWidgets('the zoom glide leaves no undisposed animation behind',
      (tester) async {
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
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('canvas-zoom-in')));
      await tester.pumpAndSettle();
    }
  }, experimentalLeakTesting: LeakTesting.settings.withTrackedAll());

  testWidgets('a changed key fades without leaving an animation behind',
      (tester) async {
    Widget host(String key) => MaterialApp(
          home: Scaffold(
            body: FadeInOnChange(changeKey: key, child: Text(key)),
          ),
        );
    await tester.pumpWidget(host('a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host('b'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(host('c'));
    await tester.pumpAndSettle();
  }, experimentalLeakTesting: LeakTesting.settings.withTrackedAll());
}
