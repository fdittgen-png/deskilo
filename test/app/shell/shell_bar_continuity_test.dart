// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Reserve button is the anchor the eye follows.
//
// The endpoints of this transition were always right, and every existing
// test asserted them. The defect lived entirely in the MIDDLE: a plain
// `Align` flipped between `topCenter` and `bottomCenter`, so the button
// jumped its whole travel on the first frame and then sat perfectly
// still while the surface animated for the remaining 220 ms.
//
// So these tests sample the transition rather than its ends. A test that
// only checks where things start and stop cannot see a discontinuity
// between them — which is exactly how this shipped under a green suite.
//
// Ported with the mechanism from the Sparkilo shell, which reimplemented
// its bar as one adaptive control after shipping the swipe-away view
// this app took in #1173.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bar_visibility.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';
import '../../helpers/mock_providers.dart';

Future<ProviderContainer> pumpBar(
  WidgetTester tester, {
  bool hidden = false,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        shellBarHidden: InMemoryShellFlagStore(hidden),
      ),
      // COPY the view's metrics rather than replacing them: a bare
      // MediaQueryData has a zero size, and `ShellBarMetrics.barHeightOf`
      // reads the height to pick the short-screen bar (#1183). The first
      // version of this wrapper silently put every test on a 48 dp bar.
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(disableAnimations: disableAnimations),
        child: const DeskiloApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ShellBottomBar)),
  );
}

double buttonY(WidgetTester tester) =>
    tester.getCenter(find.byType(ShellCenterButton)).dy;

/// Every position the button occupies across a full transition, one
/// sample per frame.
Future<List<double>> track(
  WidgetTester tester,
  ProviderContainer container, {
  required bool toHidden,
}) async {
  final samples = <double>[buttonY(tester)];
  await container.read(shellBarHiddenProvider.notifier).set(toHidden);
  const step = Duration(milliseconds: 16);
  // One frame past the declared duration, so the settle is included.
  final frames = kShellBarHideDuration.inMilliseconds ~/ 16 + 2;
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
    samples.add(buttonY(tester));
  }
  return samples;
}

double biggestStep(List<double> samples) {
  var worst = 0.0;
  for (var i = 1; i < samples.length; i++) {
    final d = (samples[i] - samples[i - 1]).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

void main() {
  group('the button never teleports', () {
    testWidgets('hiding moves it in trackable steps, not one jump',
        (tester) async {
      final container = await pumpBar(tester);
      final samples = await track(tester, container, toHidden: true);

      // A FRACTION of the travel, not a pixel count: the old `Align`
      // flip put the entire distance into one frame, so what this has to
      // catch is "one frame carried most of it" — and that stays true if
      // the bar's geometry ever changes. Standard easing is fast at the
      // start, so a third is generous without being meaningless.
      final travel = (samples.last - samples.first).abs();
      expect(
        biggestStep(samples),
        lessThan(travel / 3),
        reason: 'a per-frame jump the eye cannot follow is the whole '
            'defect — the endpoints were never wrong. Travel $travel, '
            'worst step ${biggestStep(samples)}. Samples: $samples',
      );
    });

    testWidgets('showing it again is equally continuous', (tester) async {
      final container = await pumpBar(tester, hidden: true);
      final samples = await track(tester, container, toHidden: false);
      final travel = (samples.last - samples.first).abs();
      expect(biggestStep(samples), lessThan(travel / 3));
    });

    testWidgets('it really does travel — a frozen button would mean the '
        'box stopped collapsing', (tester) async {
      final container = await pumpBar(tester);
      final samples = await track(tester, container, toHidden: true);
      final travel = (samples.last - samples.first).abs();

      // The bar is 64 tall with a 24 dp rise above it, and the button is
      // 56 across: 88 − 56 = 32 dp of seat to give up.
      expect(travel, greaterThan(24.0));
      expect(travel, lessThan(40.0));
    });

    testWidgets('the travel is monotonic — no overshoot, no backtrack',
        (tester) async {
      // Bounce or elasticity would read as playful. This control is
      // meant to read as physical and restrained.
      final container = await pumpBar(tester);
      final samples = await track(tester, container, toHidden: true);
      final descending = samples.last > samples.first;
      for (var i = 1; i < samples.length; i++) {
        final delta = samples[i] - samples[i - 1];
        expect(descending ? delta : -delta, greaterThanOrEqualTo(-0.01),
            reason: 'frame $i reversed direction');
      }
    });
  });

  group('the one seam that decides whether anything animates', () {
    testWidgets('reduced motion gets the END STATE, not a faster journey',
        (tester) async {
      // #611 — `motionDuration` is the question every animated surface
      // in this app asks, and an AnimationController has to ask it like
      // the rest. A controller that ignored it would be the one place
      // the setting did not reach.
      final container = await pumpBar(tester, disableAnimations: true);
      final shown = buttonY(tester);

      await container.read(shellBarHiddenProvider.notifier).set(true);
      await tester.pump();
      final afterOneFrame = buttonY(tester);
      await tester.pumpAndSettle();

      expect(afterOneFrame, moreOrLessEquals(buttonY(tester), epsilon: 0.01),
          reason: 'it must be finished on the frame the preference '
              'changed, not easing towards it');
      expect(afterOneFrame, isNot(moreOrLessEquals(shown, epsilon: 0.5)),
          reason: 'and it must actually have moved — instant is not the '
              'same as inert');
    });
  });

  group('the shadow says what the button is sitting on', () {
    BoxShadow glow(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(find.descendant(
          of: find.byType(ShellCenterButton),
          matching: find.byType(DecoratedBox),
        ))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => (d.boxShadow ?? const []).isNotEmpty)
        .boxShadow!
        .first;

    testWidgets('docked it is tight, floating it is soft and wide',
        (tester) async {
      await pumpBar(tester);
      final docked = glow(tester);
      await pumpBar(tester, hidden: true);
      final floating = glow(tester);

      expect(
        floating.blurRadius,
        greaterThan(docked.blurRadius),
        reason: 'over a floor plan it needs an atmospheric shadow, not '
            'the tight one a surface beneath it justified',
      );
      expect(floating.offset.dy, greaterThan(docked.offset.dy));
    });

    testWidgets('and it gets there gradually', (tester) async {
      final container = await pumpBar(tester);
      final start = glow(tester).blurRadius;
      await container.read(shellBarHiddenProvider.notifier).set(true);
      // The first pump rebuilds with the new target and STARTS the
      // controller; it does not advance it.
      await tester.pump();
      final samples = <double>[];
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(glow(tester).blurRadius);
      }
      await tester.pumpAndSettle();
      final end = glow(tester).blurRadius;

      expect(samples.first, greaterThan(start));
      expect(
        samples.any((v) => v > start && v < end),
        isTrue,
        reason: 'a shadow that arrives at its final value on frame one is '
            'the same discontinuity in a different property',
      );
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]),
            reason: 'frame $i went backwards');
      }
    });
  });
}
