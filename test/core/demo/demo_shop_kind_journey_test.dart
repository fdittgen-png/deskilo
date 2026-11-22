// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 (G16) -- a new shop owner, in the Demo, at a phone's width: see shop_kind_walk_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_kind_walk_kit.dart';

void main() {
  testWidgets('on a phone: a freelancer becomes a shop (a bakery), is proposed the stock and finds the Stock page', (tester) async {
    await walkShopKind(tester, const Size(390, 2400));
  });
}
