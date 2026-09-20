// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1379 — the Demo bar works where it is actually mounted.
//
// It renders from the app's own `builder`, which is ABOVE the Navigator.
// Everything up there is outside the Navigator's Overlay, so a tooltip,
// a popup menu, a dialog or a route push from the bar has nowhere to go:
// the first attempt shipped a `PopupMenuButton` and it threw *No Overlay
// widget found* the moment the demo was entered, taking the layout down
// with it.
//
// The test therefore mounts the bar in exactly that position — in a
// `MaterialApp.builder`, wrapping the Navigator rather than sitting
// inside it — and fails on any framework exception, which is what that
// class of mistake produces. Mounting it inside `home` instead would
// give it an Overlay and prove nothing.
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/motion/motion.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(BuildContext context, Widget? child) =>
    DemoControls(child: child ?? const SizedBox());

void main() {
  /// The bar exactly where the app puts it: in `MaterialApp.builder`,
  /// wrapping the Navigator rather than sitting inside it. Nothing else
  /// of the app is here, so no boot timer outlives the test — but the
  /// position, which is the whole point, is identical.
  Widget appShapedLikeTheRealOne() => const DemoWorkspace(
        child: MaterialApp(
          home: Scaffold(body: SizedBox()),
          builder: _wrap,
        ),
      );

  testWidgets('the bar is usable above the Navigator, where it is mounted',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: appShapedLikeTheRealOne(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'a control up here that needs an Overlay throws — the defect '
          'this test exists for',
    );
    expect(find.byKey(DemoControls.resetKey), findsOneWidget);
    expect(find.byKey(DemoControls.viewAsKey), findsOneWidget);
    expect(find.byKey(DemoControls.leaveKey), findsOneWidget);

    // The persona ring: one tap moves to the next, with no menu to open.
    expect(
      container.read(demoSessionControllerProvider).persona,
      DemoPersona.owner,
    );
    await tester.tap(find.byKey(DemoControls.viewAsKey));
    await tester.pumpAndSettle();
    expect(
      container.read(demoSessionControllerProvider).persona,
      DemoPersona.member,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar honours reduced motion, because it has no motion to '
      'reduce', (tester) async {
    // #1381 — the Demo surfaces are the bar and the entry sheet. Neither
    // animates, so the check is that turning motion off changes nothing
    // and breaks nothing: a Demo-specific surface that only worked with
    // animations on would be a surface nobody with the accessibility
    // setting could use.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Future<String> barText({required bool animations}) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MotionSettings(
            animationsEnabled: animations,
            child: const DemoWorkspace(
              child: MaterialApp(
                home: DemoControls(child: Scaffold(body: SizedBox())),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join('|');
    }

    final moving = await barText(animations: true);
    final still = await barText(animations: false);
    expect(still, moving);
    expect(still, contains('Demo'));
  });

  testWidgets('the bar fits a 360 dp screen without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoWorkspace(
          child: MaterialApp(
            home: DemoControls(child: Scaffold(body: SizedBox())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
