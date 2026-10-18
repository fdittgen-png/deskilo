// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2571 -- the accounting settings state how long the space's country makes it
// keep each kind of record, with the statute and whether the rule is
// confirmed: a German space reads 8 years for invoices and 10 for books, a
// British one 6 and 6; the detail names the statute and an unconfirmed rule.
import 'package:deskilo/features/money/presentation/widgets/retention_clocks_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, String country) async {
  await pumpApp(tester, Scaffold(body: RetentionClocksTile(country: country)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a German space: 8 years for invoices, 10 for books', (tester) async {
    await _pump(tester, 'DE');
    expect(find.textContaining('Invoices: 8'), findsOneWidget);
    expect(find.textContaining('Books: 10'), findsOneWidget);
  });

  testWidgets('a British space: 6 and 6, and the detail names the statute and the status', (tester) async {
    await _pump(tester, 'GB');
    expect(find.textContaining('Invoices: 6 · Books: 6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retention-clocks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retention-clocks-dialog')), findsOneWidget);
    expect(find.text('Invoices — 6 years from the end of the fiscal year'), findsOneWidget);
    expect(find.textContaining('HMRC VAT Notice 700/21'), findsWidgets);
    expect(find.textContaining('not yet confirmed'), findsWidgets);
  });

  testWidgets('a country without rows of its own reads the shared rule', (tester) async {
    await _pump(tester, 'ZZ');
    expect(find.textContaining('Invoices: 10'), findsOneWidget);
  });
}
