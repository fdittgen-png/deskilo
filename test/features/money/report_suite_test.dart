// SPDX-License-Identifier: 0BSD
//
// The report SUITE (#494): the financial agreement, the monthly
// payments report and the workspace report — engine documents with
// their own presets, self-service on the Money tab, sendable per member
// and exportable from workspace settings.
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invoices_test.dart' show pumpInvoices, seededMoney;

void main() {
  group('the three new documents ship the four presets (#494)', () {
    for (final doc in ['agreement', 'payments', 'workspace']) {
      test(doc, () {
        final presets = presetsForDoc(doc, null);
        expect(presets.map((p) => p.id),
            ['classic', 'simple', 'verbose', 'formal']);
        expect(presets.first.bands.header,
            defaultBandsForDoc(doc, null).header);
        expect(defaultBandsForDoc(doc, null).hasBands, isTrue);
      });
    }
  });

  test('extraDocs round-trip through the template jsonb (#494)', () {
    const template = InvoicePdfTemplate(extraDocs: {
      'agreement': ReportBands(header: '# A'),
      'workspace': ReportBands(body: 'B'),
    });
    final restored = InvoicePdfTemplate.fromJson(
        template.toJson().cast<String, dynamic>());
    expect(restored.docBands('agreement')!.header, '# A');
    expect(restored.docBands('workspace')!.body, 'B');
    expect(restored.docBands('payments'), isNull);
    // withDoc replaces one and keeps the rest.
    final next =
        restored.withDoc('payments', const ReportBands(header: '# P'));
    expect(next.docBands('agreement')!.header, '# A');
    expect(next.docBands('payments')!.header, '# P');
  });

  testWidgets('the editor lists the three documents as chips and saves '
      'their bands into extraDocs (#494)', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-doc-agreement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-save')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    final agreement = money.pdfTemplate.docBands('agreement');
    expect(agreement, isNotNull);
    expect(agreement!.header, contains('Financial agreement'));
    // The invoice's own bands stayed untouched.
    expect(money.pdfTemplate.invoiceBands.hasBands, isFalse);
  });

  testWidgets('the Money tab offers the self-service documents with '
      'quick view / download / share (#494)', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    // Back to the Money tab root (pumpInvoices navigates to /invoices).
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(
        find.byKey(const ValueKey('agreement-report-button')));
    expect(find.byKey(const ValueKey('agreement-report-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('payments-report-button')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('agreement-report-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-doc-quick')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-doc-download')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('member-doc-share')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('member-doc-quick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget);
    // #496 — the DE fixture workspace resolves the document language to
    // German: the member's self-service agreement is a Finanzvereinbarung.
    expect(find.textContaining('Finanzvereinbarung'), findsWidgets);
  });
}
