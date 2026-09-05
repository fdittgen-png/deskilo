// SPDX-License-Identifier: 0BSD
//
// #874 — every document sent to a person conforms to the letter
// standard when it has no design of its own: proven on the PDF the
// default positioned layouts produce (docs/AGENT_RULES.md, the
// window-envelope contract), and the resolution rule around them.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/presentation/report_layout_defaults.dart';
import 'package:deskilo/features/money/presentation/report_sample_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/pdf_geometry.dart';

const _kinds = ['invoice', 'proforma', 'statement', 'agreement', 'payments', 'usage', 'r1', 'r3'];

pw.Font _ttf(String path) =>
    pw.Font.ttf(File(path).readAsBytesSync().buffer.asByteData());

Map<String, Object?> _data() => {
      ...sampleReportData(null),
      'client_name': 'Guilhem MARTIN',
      'client_address': 'SASU KaloA\n209 rue Jean Bart\n31670 LABÈGE',
      'reminder_level': '1',
      'days_open': '12 days',
      'reminder_date': '2026-09-05',
    };

void main() {
  group('the resolution rule', () {
    const designed = InvoicePdfTemplate(
        layouts: {'invoice': '<report-layout page="A4"/>'});
    test('a designed layout wins; the default fills in for a person-facing '
        'kind when the standard is on; nothing otherwise', () {
      expect(resolveLayoutXml(template: designed, kindId: 'invoice', letterStandard: true),
          '<report-layout page="A4"/>');
      expect(
          resolveLayoutXml(
              template: InvoicePdfTemplate.empty,
              kindId: 'invoice',
              letterStandard: true,
              bandsDesigned: true),
          isNull,
          reason: 'bands the owner customised are a design too');
      expect(resolveLayoutXml(template: InvoicePdfTemplate.empty, kindId: 'usage', letterStandard: true),
          contains('<recipient window="fr"/>'));
      expect(resolveLayoutXml(template: InvoicePdfTemplate.empty, kindId: 'usage', letterStandard: false),
          isNull);
      expect(resolveLayoutXml(template: InvoicePdfTemplate.empty, kindId: 'coa', letterStandard: true),
          isNull, reason: 'a chart of accounts is not posted to anyone');
    });
  });

  group('every person-facing default CONFORMS on the sheet', () {
    for (final kind in _kinds) {
      test(kind, () async {
        final xml = defaultLetterLayoutXml(kind, const LetterStrings());
        final data = _data();
        final document = renderLayoutDocument(xml, data);
        final bytes = await buildLayoutPdf(
          document: document,
          data: data,
          documentTitle: kind,
          pageLabel: 'Page',
          baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
          boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
        );
        final page1 = textPositions(bytes).where((i) => i.page == 1).toList();
        expect(page1, isNotEmpty);
        final inWindow = page1.where((i) => i.xMm >= 100 && i.yMm >= 40 && i.yMm <= 90);
        expect(inWindow, isNotEmpty, reason: '$kind: no recipient in the window');
        for (final i in inWindow) {
          expect(i.xMm, greaterThanOrEqualTo(109.5), reason: '$kind $i');
          expect(i.yMm, inInclusiveRange(44.5, 85), reason: '$kind $i');
        }
        // The letterhead stays above the aperture, the body under it.
        final leftColumn = page1.where((i) => i.xMm < 100);
        expect(leftColumn.where((i) => i.yMm > 45 && i.yMm < 89.5), isEmpty,
            reason: '$kind: ink beside/under the aperture');
        expect(leftColumn.where((i) => i.yMm >= 89.5 && i.yMm < 250), isNotEmpty,
            reason: '$kind: no body');
        expect(page1.where((i) => i.yMm >= 265), isNotEmpty,
            reason: '$kind: no footer on page 1');
      });
    }
  });
}
