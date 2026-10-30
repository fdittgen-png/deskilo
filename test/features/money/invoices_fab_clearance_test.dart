// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3072 — the invariant: the floating "new invoice" button never covers the
// lists beneath it, so the action of the last row stays reachable, on a
// desktop window and on a phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart';

void main() {
  for (final size in const [Size(1192, 760), Size(390, 844)]) {
    testWidgets('the lists end above the floating button at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpInvoices(tester, size: size);
      final fab = tester.getRect(
        find.byKey(const ValueKey('invoice-create-button')),
      );
      final lists = tester.getRect(find.byType(TabBarView));
      expect(lists.bottom, lessThanOrEqualTo(fab.top),
          reason: 'the button sits in its own band under the lists');
    });
  }
}
