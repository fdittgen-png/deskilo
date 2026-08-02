// SPDX-License-Identifier: 0BSD
//
// Reduce motion (#402, wiki 26): when the platform asks for reduced
// motion, every animation collapses to zero — decided once in the token
// class, not re-decided per call site.

import 'package:deskilo/core/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> contextWith(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(builder: (context) {
          captured = context;
          return const SizedBox();
        }),
      ),
    );
    return captured;
  }

  testWidgets('animations run at their token durations by default',
      (tester) async {
    final context = await contextWith(tester, disableAnimations: false);
    expect(AppMotion.viewSwitchOf(context), AppMotion.viewSwitch);
    expect(AppMotion.loadingFadeInOf(context), AppMotion.loadingFadeIn);
  });

  testWidgets('the platform reduce-motion setting collapses every token '
      'to zero', (tester) async {
    final context = await contextWith(tester, disableAnimations: true);
    expect(AppMotion.viewSwitchOf(context), Duration.zero);
    expect(AppMotion.loadingFadeInOf(context), Duration.zero);
  });
}
