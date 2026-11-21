// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- the freelancer's business walked on a desk. One size per file: a second widget test in one
// process reads the first one's cached settings and waits on them forever.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freelancer_walk_kit.dart';

void main() {
  testWidgets(
    'on a desk, the same entries reach the same pages',
    (tester) => walkKessler(tester, const Size(1440, 1000)),
  );
}
