// SPDX-License-Identifier: 0BSD
//
// Report WYSIWYG editor + image library (#488): the `![name]` markup,
// the lossless visual↔markup round-trip, the visual rows editing the
// same bands, and images flowing into preview and PDF.
import 'dart:convert' show base64Decode;

import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/widgets/report_preview.dart';
import 'package:deskilo/features/money/presentation/widgets/report_visual_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'invoices_test.dart' show pumpInvoices, seededMoney;

/// A valid 1×1 PNG — enough for the renderers to draw.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
    'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

void main() {
  group('![name] markup (#488)', () {
    test('parses to a ReportImage block', () {
      final blocks = parseReportMarkup('![logo]\nHello');
      expect(blocks.first, isA<ReportImage>());
      expect((blocks.first as ReportImage).name, 'logo');
    });

    test('reportImageRefs walks bands AND columns', () {
      final report = InvoiceReport(
        header: parseReportMarkup(':::\n![logo]\n|||\nX\n:::'),
        body: parseReportMarkup('![stamp]'),
        footer: const [],
      );
      expect(reportImageRefs(report), {'logo', 'stamp'});
    });
  });

  group('visual line model (#488)', () {
    test('round-trips every markup kind losslessly', () {
      const source = '# Title\n'
          '## Section\n'
          'Plain text\n'
          '> small print\n'
          'a | b | c\n'
          '= Total | 10\n'
          '---\n'
          '\n'
          '![logo]\n'
          ':::\n'
          '|||\n'
          '{% if voided %}void{% endif %}';
      final lines =
          source.split('\n').map(ReportVisualLine.parse).toList();
      expect(lines.map((l) => l.serialize()).join('\n'), source);
      expect(lines[0].kind, ReportLineKind.title);
      expect(lines[4].kind, ReportLineKind.row);
      expect(lines[7].kind, ReportLineKind.spacer);
      expect(lines[8].kind, ReportLineKind.image);
      expect(lines[9].kind, ReportLineKind.columnsFence);
      expect(lines[11].kind, ReportLineKind.logic);
    });
  });

  testWidgets('the quick-preview renderer draws a resolved image and '
      'skips an unresolved one (#488)', (tester) async {
    final report = InvoiceReport(
      header: parseReportMarkup('![logo]\n![missing]'),
      body: const [],
      footer: const [],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReportBlocksView(report: report, images: {'logo': _png}),
      ),
    ));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the editor switches to VISUAL mode: typed rows edit the '
      'same band and survive the switch back (#488)', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-mode')));
    await tester.tap(find.text('Visual'));
    await tester.pumpAndSettle();

    // #498 — the band renders STYLED; line 0 is the layout's columns
    // fence (a boundary), line 1 the title. Tap it → in-place editor.
    await tester.ensureVisible(
        find.byKey(const ValueKey('visual-header-line-1')));
    await tester.tap(find.byKey(const ValueKey('visual-header-line-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('visual-header-field-1')),
      'MY COMPANY',
    );
    await tester
        .tap(find.byKey(const ValueKey('visual-header-done-1')));
    await tester.pumpAndSettle();
    // Back to markup: the visual edit is IN the controller.
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-mode')));
    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();
    final headerText = tester
        .widget<TextField>(
            find.byKey(const ValueKey('invoice-template-header')))
        .controller!
        .text;
    expect(headerText, contains('# MY COMPANY'));
  });

  testWidgets('the design surface is WYSIWYG (#498): the facture layout '
      'renders side-by-side columns and a token palette inserts a field '
      'at the cursor', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-mode')));
    await tester.tap(find.text('Visual'));
    await tester.pumpAndSettle();

    // No raw-markup row list: the band paints STYLED elements —
    // tapping the title line opens the in-place editor with a palette.
    await tester.ensureVisible(
        find.byKey(const ValueKey('visual-header-line-1')));
    await tester.tap(find.byKey(const ValueKey('visual-header-line-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-header-palette')),
        findsOneWidget);

    // Tap a data-field chip → the token lands in the line at the cursor.
    await tester
        .tap(find.byKey(const ValueKey('visual-header-token-member')));
    await tester.pumpAndSettle();
    final text = tester
        .widget<TextField>(
            find.byKey(const ValueKey('visual-header-field-1')))
        .controller!
        .text;
    expect(text, contains('{{ member }}'));
  });

  testWidgets('Insert image uploads to the library and drops ![name] '
      'into the header band (#488)', (tester) async {
    final money = await seededMoney();
    money.reportImages['logo.png'] = _png;
    await pumpInvoices(tester, money: money);

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-image-logo.png')),
        findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('report-image-logo.png')));
    await tester.pumpAndSettle();

    final headerText = tester
        .widget<TextField>(
            find.byKey(const ValueKey('invoice-template-header')))
        .controller!
        .text;
    expect(headerText, contains('![logo.png]'));
  });
}
