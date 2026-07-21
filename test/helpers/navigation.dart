// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app boots on the Reserve hub (the centre button's form is the
/// default screen); tests exercising the Plan tab switch to it first.
/// Scoped to the bar: the hub's view toggle also carries a 'Plan' label.
Future<void> switchToPlanTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ShellBottomBar),
      matching: find.text('Plan'),
    ),
  );
  await tester.pumpAndSettle();
}
