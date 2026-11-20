// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — the walk the two postures share: the guide of the Demo practice (a business whose kind keeps places
// off), walked as its owner: the list, "Add more" and every step page that is
// offered speak of what the practice does, never of a seat, a desk, a level,
// a floor plan, a kiosk, a badge, a check-in, a meeting room, a half-day or a
// day pack. Leipzig, a coworking space, keeps its words.
import 'package:deskilo/features/workspace/domain/setup_steps_for_kind.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_practice_owner_walk.dart';
import 'place_vocabulary.dart';

Future<void> settleFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// The practice's guide, every page it offers, at [size].
Future<void> walkPracticeGuide(WidgetTester tester, Size size) async {
  final (_, container, router) = await openDemoSpaceAsOwner(
    tester,
    space: 'practice',
    size: size,
  );
  final id = container.read(currentWorkspaceProvider).value!.id;
  final flagsBefore = {
    ...container.read(currentWorkspaceProvider).value!.featureFlags,
  };
  router.go('/setup');
  await settleFrames(tester);
  final add = find.byKey(const ValueKey('setup-guide-add-more'));
  if (add.evaluate().isNotEmpty) {
    await tester.ensureVisible(add);
    await tester.tap(add);
    await settleFrames(tester);
  }
  expect(placeWordsShown(tester), isEmpty, reason: 'the guide');
  for (final noPlaceStep in setupStepsNeedingPlaces) {
    expect(
      find.byKey(ValueKey('setup-step-$noPlaceStep'), skipOffstage: false),
      findsNothing,
      reason:
          'no place step ($noPlaceStep) is offered, in the list or under Add more',
    );
  }
  final problems = <String, List<String>>{};
  // The questions the guide's required task asks, with their examples.
  router.go('/setup/levels');
  await settleFrames(tester);
  final asked = placeWordsShown(tester);
  if (asked.isNotEmpty) problems['the questionnaire'] = asked;
  final status = await container.read(workspaceSetupStatusProvider(id).future);
  for (final step in status.steps) {
    if (setupStepsNeedingPlaces.contains(step.step)) continue;
    // "Prices and plans" prices presence (levels, extra half-days, day packs):
    // it is not a step of a business without places once the server's
    // detector says so (the migration that follows this one).
    if (step.step == 'pricing') continue;
    router.go('/setup/step/${step.step}');
    await settleFrames(tester);
    final words = placeWordsShown(tester);
    if (words.isNotEmpty) problems['the page of ${step.step}'] = words;
  }
  expect(problems, isEmpty, reason: 'place words on pages of the guide');
  expect(
    container.read(currentWorkspaceProvider).value!.featureFlags,
    flagsBefore,
    reason: 'visiting the guide writes no flag',
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
