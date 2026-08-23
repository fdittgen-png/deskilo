// SPDX-License-Identifier: 0BSD
//
// Route transitions of the motion pass (#611): the theme carries
// fade-forwards transitions for Android/desktop and keeps iOS's native
// Cupertino back-swipe; `animations: false` (the uiAnimations feature
// off) swaps in an instant builder for EVERY platform, and the whole
// app then pushes routes with no transition at all.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

void main() {
  test('the animated theme carries a page-transitions theme for every '
      'shipped platform (fade-forwards; Cupertino kept on iOS)', () {
    for (final theme in [
      DeskiloTheme.light(),
      DeskiloTheme.dark(),
      DeskiloTheme.warm(),
    ]) {
      final builders = theme.pageTransitionsTheme.builders;
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(builders[platform], isNotNull,
            reason: 'no transitions builder for $platform');
      }
      // Android and iOS deliberately differ: fade-forwards vs. the
      // native Cupertino back-swipe.
      expect(
        builders[TargetPlatform.android].runtimeType,
        builders[TargetPlatform.linux].runtimeType,
      );
    }
  });

  test('animations: false swaps ALL platforms to one instant builder',
      () {
    final builders = DeskiloTheme.light(animations: false)
        .pageTransitionsTheme
        .builders;
    final types = {
      for (final platform in TargetPlatform.values)
        builders[platform].runtimeType,
    };
    expect(types, hasLength(1),
        reason: 'instant mode must not keep a per-platform transition');
    expect(types.single.toString(), contains('Instant'));
  });

  testWidgets(
      'the uiAnimations feature OFF reaches the app: instant route '
      'transitions in the theme and MotionSettings disabled below the '
      'navigator', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: const {'uiAnimations': false},
          ),
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(
      Theme.of(context)
          .pageTransitionsTheme
          .builders[TargetPlatform.android]
          .runtimeType
          .toString(),
      contains('Instant'),
    );
    expect(MotionSettings.enabledOf(context), isFalse);
    expect(
      motionDuration(context, const Duration(milliseconds: 250)),
      Duration.zero,
    );
  });

  testWidgets('with the flag at its default the app animates',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(
      Theme.of(context)
          .pageTransitionsTheme
          .builders[TargetPlatform.android]
          .runtimeType
          .toString(),
      isNot(contains('Instant')),
    );
    expect(MotionSettings.enabledOf(context), isTrue);
  });
}
