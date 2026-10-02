// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — My account lives in Me: the avatar in the space's bar leads
// there, and the Me tab holds the rows that used to sit in Settings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openMyAccount(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('shell-back-to-me')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('me-tab-me')));
  await tester.pumpAndSettle();
}

/// Privacy & data, reached from Me since #1823 (it was a shield in the
/// space's bar).
Future<void> openMyPrivacy(WidgetTester tester) async {
  await openMyAccount(tester);
  final row = find.byKey(const ValueKey('me-privacy'));
  await tester.scrollUntilVisible(row, 200,
      scrollable: find
          .descendant(
              of: find.byKey(const ValueKey('me-account-list')),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}
