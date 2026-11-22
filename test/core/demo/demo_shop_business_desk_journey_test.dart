// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 (PR B) -- the Épicerie du Marché in the Demo at a desk's width: see shop_business_walk_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_business_walk_kit.dart';

void main() {
  testWidgets('on a desk: Bruno enters the Épicerie du Marché, finds its goods and moves three mugs to a shelf', (tester) async {
    await walkShopBusiness(tester, const Size(1440, 2400));
  });
}
