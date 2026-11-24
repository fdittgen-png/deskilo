// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- a customer of the freelancer reads her invoice on a phone. One
// size per file: a second widget test in one process reads the first one's
// cached settings and waits on them forever.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freelancer_customer_walk_kit.dart';

void main() {
  testWidgets(
    "on a phone, Ada finds Kessler Conseil's invoice to Lindner Beratung in Me, apart from her own",
    (tester) => walkLindnerReads(tester, const Size(390, 844)),
  );
}
