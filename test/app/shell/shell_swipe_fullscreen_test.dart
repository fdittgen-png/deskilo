// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1173 — the swipe-away full-screen view, ported from the Sparkilo
// shell. A downward swipe slides the tab surface out and leaves the
// Reserve button behind; three independent ways bring it back, one of
// them reachable without any gesture at all.
//
// The regression this file exists to prevent is Sparkilo's #4103: a
// long-press recognizer that competes with the button's own tap, so the
// primary action answers a third of a second late — or not at all.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/app/shell/shell_swipe_coach_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  InMemoryShellFlagStore? hiddenStore,
  InMemoryShellFlagStore? coachStore,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // The harness defaults the hint to SEEN, so only the tests that
      // are about it hand in a store that says otherwise.
      overrides: standardTestOverrides(
        shellBarHidden: hiddenStore,
        shellSwipeCoach: coachStore,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _bar => find.byType(ShellBottomBar);
Finder get _surface => find.byKey(const ValueKey('shell-bar-surface'));
Finder get _button => find.byType(ShellCenterButton);

/// Throw the bar [dy] logical pixels in 100 ms — comfortably past the
/// velocity floor a resting finger cannot reach.
Future<void> fling(WidgetTester tester, double dy) async {
  await tester.fling(_bar, Offset(0, dy), 800);
  await tester.pumpAndSettle();
}

bool isHidden(WidgetTester tester) =>
    tester.widget<IgnorePointer>(_surface).ignoring;

void main() {
  testWidgets('a downward swipe hides the bar and keeps the Reserve button',
      (tester) async {
    await pumpApp(tester);
    expect(isHidden(tester), isFalse);
    final shownHeight = tester.getSize(_bar).height;

    await fling(tester, 300);

    expect(isHidden(tester), isTrue,
        reason: 'the tab surface must go inert, not merely move');
    expect(_button, findsOneWidget,
        reason: 'the one piece of chrome left on screen is the way back');
    expect(tester.getSize(_bar).height, lessThan(shownHeight),
        reason: 'the strip the bar occupied goes back to the content');
  });

  testWidgets('an upward swipe brings it back', (tester) async {
    await pumpApp(tester, hiddenStore: InMemoryShellFlagStore(true));
    expect(isHidden(tester), isTrue, reason: 'the stored choice is restored');

    await fling(tester, -300);

    expect(isHidden(tester), isFalse);
  });

  testWidgets('a short drag is a rest, not a swipe', (tester) async {
    await pumpApp(tester);
    // #1265 — this used to read "a SLOW drag", and under the velocity
    // gate that was the whole rule: below kShellBarSwipeVelocity,
    // nothing happened however far the finger went. The bar is dragged
    // directly now, so travel decides when a throw does not, and a slow
    // pull past the threshold DOES collapse it (asserted in
    // shell_bar_drag_test).
    //
    // What still holds, and what this is now about: 40 px of which the
    // recognizer swallows 18 as touch slop leaves ~0.34 of a 64 dp
    // extent — under the 0.45 settle threshold, so it springs back.
    await tester.timedDrag(
      _bar,
      const Offset(0, 40),
      const Duration(milliseconds: 800),
    );
    await tester.pumpAndSettle();
    expect(isHidden(tester), isFalse);
  });

  testWidgets('a long-press on the Reserve button toggles, and the choice '
      'is remembered', (tester) async {
    final store = InMemoryShellFlagStore();
    await pumpApp(tester, hiddenStore: store);

    await tester.longPress(_button);
    await tester.pumpAndSettle();
    expect(isHidden(tester), isTrue);
    expect(store.value, isTrue);
    expect(store.writes, 1);

    await tester.longPress(_button);
    await tester.pumpAndSettle();
    expect(isHidden(tester), isFalse);
    expect(store.value, isFalse);
  });

  testWidgets('#4103 — the Reserve tap still fires, and does NOT toggle',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(isHidden(tester), isFalse,
        reason: 'a tap must keep the meaning it has always had');
    expect(find.byKey(const ValueKey('reserve-scan-button')), findsAny,
        reason: 'the tap reached the Reserve hub');
  });

  testWidgets('a double-tap on the tab surface toggles', (tester) async {
    await pumpApp(tester);
    final tab = tester.getCenter(find.byType(ShellBarTab).first);
    await tester.tapAt(tab);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(tab);
    await tester.pumpAndSettle();
    expect(isHidden(tester), isTrue);
  });

  testWidgets('the hidden bar is excluded from semantics, so a screen '
      'reader cannot land on a tab that is gone', (tester) async {
    await pumpApp(tester, hiddenStore: InMemoryShellFlagStore(true));
    final excluder = tester.widget<ExcludeSemantics>(
      find.byKey(const ValueKey('shell-bar-surface-semantics')),
    );
    expect(excluder.excluding, isTrue);
  });

  group('the coach mark', () {
    testWidgets('introduces the gesture once, then never again',
        (tester) async {
      final coach = InMemoryShellFlagStore();
      await pumpApp(tester, coachStore: coach);
      expect(find.byType(ShellSwipeCoachMark), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shell-swipe-coach-dismiss')));
      await tester.pumpAndSettle();

      expect(find.byType(ShellSwipeCoachMark), findsNothing);
      expect(coach.value, isTrue, reason: 'the dismissal is remembered');
    });

    testWidgets('performing the gesture counts as learning it',
        (tester) async {
      final coach = InMemoryShellFlagStore();
      await pumpApp(tester, coachStore: coach);
      expect(find.byType(ShellSwipeCoachMark), findsOneWidget);

      await fling(tester, 300);

      expect(coach.value, isTrue);
      expect(find.byType(ShellSwipeCoachMark), findsNothing);
    });

    testWidgets('never appears over an already-hidden bar', (tester) async {
      await pumpApp(
        tester,
        hiddenStore: InMemoryShellFlagStore(true),
        coachStore: InMemoryShellFlagStore(),
      );
      expect(find.byType(ShellSwipeCoachMark), findsNothing,
          reason: 'whoever hid the bar has plainly found the gesture');
    });

    testWidgets('retires itself rather than nagging', (tester) async {
      await pumpApp(tester, coachStore: InMemoryShellFlagStore());
      expect(find.byType(ShellSwipeCoachMark), findsOneWidget);
      await tester.pump(ShellSwipeCoachMark.linger);
      await tester.pumpAndSettle();
      expect(find.byType(ShellSwipeCoachMark), findsNothing);
    });
  });
}
