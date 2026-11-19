// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — the same walk at a desk, and Leipzig, a coworking space, as the
// control: its guide keeps its place steps and its place words.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_guide_walk.dart';
import '../../helpers/demo_practice_owner_walk.dart';
import '../../helpers/place_vocabulary.dart';

void main() {
  testWidgets('the practice owner\'s guide at a desk reads no place word and '
      'offers no place step', (tester) async {
    await walkPracticeGuide(tester, const Size(1440, 900));
  });

  testWidgets('a coworking space (Leipzig) keeps its place words in the '
      'questionnaire of its guide', (tester) async {
    final (_, _, router) = await openDemoSpaceAsOwner(
      tester,
      space: 'leipzig',
      size: const Size(1440, 900),
    );
    router.go('/setup/levels');
    await settleFrames(tester);
    expect(placeWordsShown(tester), isNotEmpty);
  });
}
