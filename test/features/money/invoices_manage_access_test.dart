// SPDX-License-Identifier: 0BSD
//
// #871 — Finances → Invoices hands off to invoice MANAGEMENT the way
// every other tab does: a management row (icon, verb, chevron), not a
// button repeating the tab's name. Pins the label, the key and the
// route it opens.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/screens/invoices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  testWidgets('the Invoices face offers "Manage invoices" and opens the hub',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('invoices-button'));
    await tester.ensureVisible(row);
    expect(tester.widget(row), isA<ListTile>(),
        reason: 'the management row, like the Settings tiles');
    expect(
      find.descendant(of: row, matching: find.text('Manage invoices')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.arrow_forward_ios)),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Invoices'), findsNothing,
        reason: 'the button that repeated the tab name is gone');

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(InvoicesScreen), findsOneWidget);
  });
}
