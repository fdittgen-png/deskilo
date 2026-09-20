// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bar moves with the finger, and the finger decides.
//
// #1173 shipped a velocity gate: a flick past 200 px/s toggled, anything
// slower did nothing at all. That is a switch dressed as a gesture —
// nothing moves until it has already happened, so there is no moment at
// which the control is being pulled.
//
// Ported from the Sparkilo shell's reimplementation. The split that
// makes driving this from a finger affordable is worth stating: the
// chrome is continuous, the LAYOUT is quantised. `ShellScreen` reads the
// bar's height and flips `extendBody` on it, so a box height that
// followed the drag would relayout the plan canvas on every frame of
// every swipe.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bar_collapse.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

late InMemoryShellFlagStore store;

Future<void> pumpBar(WidgetTester tester, {bool hidden = false}) async {
  store = InMemoryShellFlagStore(hidden);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(shellBarHidden: store),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

bool isHidden(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(ShellBottomBar)),
    ).read(shellBarHiddenProvider).value ??
    false;

double buttonY(WidgetTester tester) =>
    tester.getCenter(find.byType(ShellCenterButton)).dy;

double barBoxHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ShellBottomBar)).height;

/// Drags the bar [dy] pixels in eight steps, leaving the finger DOWN.
///
/// The first move clears the touch slop, which the recognizer swallows —
/// so `dy` is the travel the collapse actually sees, not the distance
/// the finger covered.
Future<TestGesture> dragBy(WidgetTester tester, double dy) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byType(ShellBottomBar)));
  await gesture.moveBy(Offset(0, dy.isNegative ? -20 : 20));
  await tester.pump();
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

void main() {
  group('the chrome moves with the finger', () {
    testWidgets('a part pull leaves the bar part collapsed, and decides '
        'nothing until the finger lifts', (tester) async {
      await pumpBar(tester);
      final expanded = buttonY(tester);

      // The drag extent is the bar's own height (64 dp), so ~16 dp of
      // travel is a quarter of the collapse.
      final gesture = await dragBy(tester, 16);

      expect(
        buttonY(tester),
        greaterThan(expanded),
        reason: 'the chrome must have moved before the finger lifted — '
            'that is the entire difference from the flick it replaces',
      );
      expect(isHidden(tester), isFalse,
          reason: 'nothing is decided until the finger lifts');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('abandoning below the threshold springs back', (tester) async {
      await pumpBar(tester);
      final expanded = buttonY(tester);

      // Released slowly, so velocity cannot decide it, and short enough
      // that position cannot either.
      final gesture = await dragBy(tester, 4);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(isHidden(tester), isFalse);
      expect(buttonY(tester), moreOrLessEquals(expanded, epsilon: 0.5));
    });

    testWidgets('a SLOW pull past the threshold collapses — which the '
        'velocity gate it replaces would have ignored', (tester) async {
      await pumpBar(tester);
      final gesture = await dragBy(tester, 48);
      // Long enough that the release carries no velocity at all.
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(isHidden(tester), isTrue,
          reason: 'direct manipulation means the finger having travelled '
              'is enough; #1173 required a throw');
      expect(store.value, isTrue, reason: 'and the choice persists');
    });

    testWidgets('the flick people already have still works', (tester) async {
      // #1173 shipped a velocity gate and users learned it. Making the
      // bar draggable must not cost them the gesture they have.
      await pumpBar(tester);
      await tester.fling(find.byType(ShellBottomBar), const Offset(0, 60), 900);
      await tester.pumpAndSettle();
      expect(isHidden(tester), isTrue);

      await tester.fling(
          find.byType(ShellBottomBar), const Offset(0, -60), 900);
      await tester.pumpAndSettle();
      expect(isHidden(tester), isFalse);
    });

    testWidgets('an upward pull from collapsed brings it back',
        (tester) async {
      await pumpBar(tester, hidden: true);
      final gesture = await dragBy(tester, -48);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(isHidden(tester), isFalse);
    });

    testWidgets('over-pulling is a no-op, never a rubber band',
        (tester) async {
      await pumpBar(tester);
      final gesture = await dragBy(tester, 80);
      final atEnd = buttonY(tester);
      await gesture.moveBy(const Offset(0, 400));
      await tester.pump();

      expect(buttonY(tester), moreOrLessEquals(atEnd, epsilon: 0.5),
          reason: 'there is nothing past collapsed to reveal');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(isHidden(tester), isTrue);
    });
  });

  group('layout is quantised — the cost nobody sees', () {
    testWidgets('the reserved height takes two values across a whole drag, '
        'never a third', (tester) async {
      // ShellScreen reads this height and flips `extendBody` on it. A
      // third value means it started following the finger, and the plan
      // canvas started relayouting at 60 fps.
      await pumpBar(tester);
      final seen = <double>{barBoxHeight(tester)};

      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(ShellBottomBar)));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 4));
        await tester.pump(const Duration(milliseconds: 16));
        seen.add(barBoxHeight(tester));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      seen.add(barBoxHeight(tester));

      expect(seen.length, lessThanOrEqualTo(2),
          reason: 'saw ${seen.toList()..sort()} — chrome is continuous, '
              'layout is not');
    });

    testWidgets('the button still moves continuously while it does',
        (tester) async {
      // The other half of the split: quantising the LAYOUT must not
      // quantise what the user is looking at.
      await pumpBar(tester);
      final ys = <double>[buttonY(tester)];

      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(ShellBottomBar)));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 4));
        await tester.pump(const Duration(milliseconds: 16));
        ys.add(buttonY(tester));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(ys.toSet().length, greaterThan(3),
          reason: 'the anchor should track the finger, not step');
    });
  });

  // A real drag cannot express this. Flutter's velocity estimator fits
  // over roughly the last 100 ms and reports Velocity.zero below
  // 50 px/s, so a pull followed by a fast reversal arrives at the
  // handler as a standing start — measured, at v = 0.0 with the
  // progress at exactly 0.5. Chasing a sample shape that survives that
  // fitter would be testing the fitter. The rule is a pure function for
  // this reason, and this is where it is tested.
  group('what a release settles to', () {
    test('position decides when the finger was not thrown', () {
      expect(shellBarSettleTarget(progress: 0.6, velocity: 0), 1);
      expect(shellBarSettleTarget(progress: 0.3, velocity: 0), 0);
      expect(shellBarSettleTarget(progress: 0.44, velocity: 10), 0);
      expect(shellBarSettleTarget(progress: 0.45, velocity: -10), 1,
          reason: 'the threshold is inclusive — one number, not two');
    });

    test('velocity beats position when the two disagree', () {
      expect(
        shellBarSettleTarget(progress: 0.9, velocity: -kShellBarSwipeVelocity),
        0,
        reason: 'pulled almost all the way down and then flicked back up: '
            'the finger said no, and the finger is the one holding it',
      );
      expect(
        shellBarSettleTarget(progress: 0.1, velocity: kShellBarSwipeVelocity),
        1,
        reason: 'and a decisive flick from a standing start still works — '
            'that is the gesture #1173 shipped and people learned',
      );
    });

    test('over- and under-shoot are clamped by the caller, so the rule '
        'never sees a progress outside [0, 1]', () {
      // The drag clamps as it accumulates; this pins the assumption so
      // removing that clamp fails here rather than somewhere subtle.
      expect(shellBarSettleTarget(progress: 1, velocity: 0), 1);
      expect(shellBarSettleTarget(progress: 0, velocity: 0), 0);
    });
  });

  group('the collapse is installed exactly once', () {
    testWidgets('one controller owns the whole bar', (tester) async {
      await pumpBar(tester);
      expect(find.byType(ShellBarCollapse), findsOneWidget,
          reason: 'two of these would be two progress values free to '
              'disagree — the defect this replaced, in a new shape');
    });
  });
}
