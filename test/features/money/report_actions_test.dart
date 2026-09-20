// SPDX-License-Identifier: AGPL-3.0-or-later
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

  // #1217 — an A4 sheet is 595 logical pixels wide and a phone dialog is
  // about 340, so the preview used to open at 100 %: the left margin was
  // off-screen, "Total Hors Taxe" read as "otal Hors Taxe", and reading
  // a line meant dragging the page sideways and losing your place.
  testWidgets('the quick preview opens fitted to the width and zooms',
      (tester) async {
    final money = await seededMoney();
    await pumpInvoices(tester, money: money);
    // AFTER the helper, which sets a tablet-sized view of its own.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    final invoice = money.invoices.single;
    await openInvoice(tester, invoice.id);

    final quick = find.byKey(ValueKey('invoice-quick-${invoice.id}'));
    await tester.scrollUntilVisible(quick, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(quick);
    await tester.pumpAndSettle();

    final viewer = find.byKey(const ValueKey('report-quick-preview'));
    expect(viewer, findsOneWidget);

    double scale() => tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    final fitted = scale();
    expect(fitted, lessThan(1.0),
        reason: 'a 595 px page does not fit a 400 px phone at 100 %, so '
            'it opens at whatever shows the whole width');

    await tester.tap(find.byKey(const ValueKey('preview-zoom-in')));
    await tester.pumpAndSettle();
    expect(scale(), greaterThan(fitted));

    await tester.tap(find.byKey(const ValueKey('preview-zoom-fit')));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(fitted, 0.001),
        reason: 'Fit takes you back to the whole page in one tap');
  });

  testWidgets('and never magnifies past 100 % on a wide screen',
      (tester) async {
    final money = await seededMoney();
    await pumpInvoices(tester, money: money);
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    final invoice = money.invoices.single;
    await openInvoice(tester, invoice.id);

    final quick = find.byKey(ValueKey('invoice-quick-${invoice.id}'));
    await tester.scrollUntilVisible(quick, 150,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(quick);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<InteractiveViewer>(
              find.byKey(const ValueKey('report-quick-preview')))
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      closeTo(1.0, 0.001),
      reason: 'a 595 px document blown up to fill a tablet is not what '
          'the paper looks like',
    );
  });
}
