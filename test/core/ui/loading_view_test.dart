// SPDX-License-Identifier: 0BSD
//
// #209: LoadingView masks quick loads — the spinner renders at opacity 0
// on the first frame and fades in over AppMotion.loadingFadeIn, so a load
// that resolves within the fade never flashes a spinner.
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/core/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No pumpAndSettle anywhere here: the indeterminate spinner never
  // settles — bounded pumps only.
  testWidgets('spinner starts invisible and fades in after the first frame',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingView()));

    AnimatedOpacity animatedOpacity() => tester.widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(LoadingView),
            matching: find.byType(AnimatedOpacity),
          ),
        );
    FadeTransition fade() => tester.widget<FadeTransition>(
          find.descendant(
            of: find.byType(LoadingView),
            matching: find.byType(FadeTransition),
          ),
        );

    // First frame: fully transparent (same layout as the old bare loader).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(animatedOpacity().opacity, 0);
    expect(animatedOpacity().duration, AppMotion.loadingFadeIn);
    expect(fade().opacity.value, 0);

    // Post-frame callback flips the target; the implicit animation runs.
    await tester.pump();
    expect(animatedOpacity().opacity, 1);

    await tester.pump(AppMotion.loadingFadeIn);
    expect(fade().opacity.value, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('layout parity: the indicator is centered', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoadingView()));
    await tester.pump(AppMotion.loadingFadeIn);

    expect(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });
}
