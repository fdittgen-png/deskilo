// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — the Demo practice owner at a phone: Overview does not say that
// switched-on features wait for Bookable places, and the guide names the
// practice's own task. One file for the posture: a walk of the guide's pages
// does not share a process with the next.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_practice_owner_walk.dart';

void main() {
  testWidgets('the Demo practice owner at a phone: no waiting-for-places '
      'line, the practice\'s own words in the guide', (tester) async {
    await walkPracticeOwnerSetup(tester, const Size(390, 844));
  });
}
