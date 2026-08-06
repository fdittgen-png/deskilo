// SPDX-License-Identifier: 0BSD
//
// #514 — every report exit offers the same triad: QUICK VIEW on screen
// before any PDF exists, save locally, share with any app. One shared
// sheet (runReportActions); these tests pin the invoice path and the
// bill-export path — the member-doc path is pinned in report_suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invoices_test.dart' show openInvoice, pumpInvoices, seededMoney;
import 'money_screen_test.dart' show pumpMoney;

void main() {
  testWidgets(
      'an archive invoice offers Quick view — the rendered report shows '
      'ON SCREEN, no PDF involved (#514)', (tester) async {
    final money = await seededMoney();
    await pumpInvoices(tester, money: money);
    final invoice = money.invoices.single;
    await openInvoice(tester, invoice.id);

    final quick = find.byKey(ValueKey('invoice-quick-${invoice.id}'));
    await tester.scrollUntilVisible(quick, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(quick);
    await tester.pumpAndSettle();

    // The report preview dialog — with the invoice's own number in it.
    expect(find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget);
    expect(find.textContaining(invoice.number), findsWidgets);
  });

  testWidgets(
      'the bill export opens the triad and Quick view renders the '
      'statement report on screen (#514)', (tester) async {
    await pumpMoney(tester);
    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pumpAndSettle();

    // All three actions offered.
    expect(find.byKey(const ValueKey('bill-export-quick')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-export-download')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('bill-export-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bill-export-quick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget);
  });
}
