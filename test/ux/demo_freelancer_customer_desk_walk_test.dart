// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- a customer of the freelancer reads her invoice on a desk.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'freelancer_customer_walk_kit.dart';

void main() {
  testWidgets(
    'on a desk, Ada finds the same invoice in the same place',
    (tester) => walkLindnerReads(tester, const Size(1440, 1000)),
  );
}
