// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in supply_expense_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openExpenseSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Submit an expense'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Submit an expense'));
  await tester.pumpAndSettle();
}
