// SPDX-License-Identifier: 0BSD
//
// Motion core (#611): ONE seam decides whether anything animates — the
// uiAnimations feature flag (installed by the app shell as
// MotionSettings) AND the platform's reduced-motion setting. Every
// animated surface asks motionDuration; off means Duration.zero, so
// every change lands instantly.
import 'package:deskilo/core/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _contextWith(
  WidgetTester tester, {
  bool disableAnimations = false,
  bool? flag,
}) async {
  late BuildContext captured;
  Widget child = Builder(builder: (context) {
    captured = context;
    return const SizedBox();
  });
  if (flag != null) {
    child = MotionSettings(animationsEnabled: flag, child: child);
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: child,
    ),
  );
  return captured;
}

void main() {
  const base = Duration(milliseconds: 250);

  testWidgets('motionDuration returns the base duration by default '
      '(no MotionSettings = the flag registry default ON)', (tester) async {
    final context = await _contextWith(tester);
    expect(motionDuration(context, base), base);
    expect(MotionSettings.enabledOf(context), isTrue);
  });

  testWidgets('reduced motion collapses motionDuration to zero',
      (tester) async {
    final context = await _contextWith(tester, disableAnimations: true);
    expect(motionDuration(context, base), Duration.zero);
    expect(MotionSettings.enabledOf(context), isFalse);
  });

  testWidgets('the uiAnimations flag OFF collapses motionDuration to zero',
      (tester) async {
    final context = await _contextWith(tester, flag: false);
    expect(motionDuration(context, base), Duration.zero);
  });

  testWidgets('flag ON + no reduced motion keeps the base duration',
      (tester) async {
    final context = await _contextWith(tester, flag: true);
    expect(motionDuration(context, base), base);
  });

  testWidgets('flag ON but reduced motion still wins (accessibility '
      'overrides the workspace choice)', (tester) async {
    final context =
        await _contextWith(tester, flag: true, disableAnimations: true);
    expect(motionDuration(context, base), Duration.zero);
  });

  testWidgets(
      'FadeInOnChange with motion OFF shows the new content at full '
      'opacity on the very next frame — no settle needed', (tester) async {
    Widget host(int key) => MotionSettings(
          animationsEnabled: false,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: FadeInOnChange(changeKey: key, child: Text('tab $key')),
            ),
          ),
        );
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    // ONE pump, no settle: instant means instant.
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, 1.0);
    expect(find.text('tab 1'), findsOneWidget);
  });

  testWidgets('FadeInOnChange with motion ON fades in and SETTLES at '
      'full opacity', (tester) async {
    Widget host(int key) => MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: FadeInOnChange(changeKey: key, child: Text('tab $key')),
          ),
        );
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    await tester.pump(const Duration(milliseconds: 50));
    final mid = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(mid.opacity.value, lessThan(1.0));
    await tester.pumpAndSettle();
    final done = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(done.opacity.value, 1.0);
  });

  testWidgets(
      'MotionReveal with motion OFF swaps its child instantly — a banner '
      'appears fully sized on the next frame', (tester) async {
    Widget host(bool banner) => MotionSettings(
          animationsEnabled: false,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topCenter,
                child: MotionReveal(
                child: banner
                    ? const SizedBox(
                        key: ValueKey('banner'),
                        height: 40,
                        child: Text('closed'),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(false));
    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(find.text('closed'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('banner'))).height,
      40,
    );
  });
}
