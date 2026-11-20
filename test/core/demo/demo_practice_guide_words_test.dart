// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4223 — the Demo practice owner's guide at a phone: no place step, no place
// word (the walk is `test/helpers/demo_practice_guide_walk.dart`).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_guide_walk.dart';

void main() {
  testWidgets('the practice owner\'s guide at a phone reads no place word and '
      'offers no place step', (tester) async {
    await walkPracticeGuide(tester, const Size(390, 844));
  });
}
