// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 — an expense's VAT starts with its kind: the tests open the kind picker of a sheet (`expense`, `schedule`) and pick one by its words.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Picks [label] in the `<prefix>-vat-kind` picker.
Future<void> pickVatKind(WidgetTester tester, String prefix, String label) async {
  final picker = find.byKey(ValueKey('$prefix-vat-kind'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Picks the rate called [label] in the `<prefix>-vat-rate` picker.
Future<void> pickVatRate(WidgetTester tester, String prefix, String label) async {
  final picker = find.byKey(ValueKey('$prefix-vat-rate'));
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
