// SPDX-License-Identifier: 0BSD
//
// #872 — the header and footer are FIXED page furniture, the body is
// the only thing that flows. A reader holding page 3 of an invoice must
// still see which document it is and where to pay; and page 3 must not
// repeat the letterhead, the recipient and the number box, which is
// half a page of nothing said twice.
//
// This is checked on the produced PDF rather than on the widget tree,
// because the failure it guards against — furniture silently flowing
// into the body again — looks identical in the tree and only shows up
// on the second page.
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the continuation band is its own band, and survives a round trip',
      () {
    const bands = ReportBands(
      header: '# Full letterhead',
      body: 'lines',
      footer: 'terms',
      continuation: '> {{ number }} — suite',
    );
    expect(bands.hasBands, isTrue);
    final back = ReportBands.fromJson(bands.toJson());
    expect(back.continuation, '> {{ number }} — suite');
    expect(back.header, '# Full letterhead');
  });

  test('a band set that ONLY has a continuation still counts as bands',
      () {
    // Otherwise the document would fall back to the built-in layout and
    // silently drop the one band the owner did write.
    expect(const ReportBands(continuation: 'x').hasBands, isTrue);
  });

  test('a pre-#872 file has no continuation and must stay valid', () {
    final old = ReportBands.fromJson({
      'header': 'h',
      'body': 'b',
      'footer': 'f',
    });
    expect(old.continuation, isEmpty,
        reason: 'empty means: draw the built-in strip');
    expect(old.hasBands, isTrue);
  });

  test('the renderer produces the continuation band beside the others',
      () {
    final report = renderReportBands(
      bands: const ReportBands(
        header: '# {{ workspace }}',
        body: 'Total | {{ total }}',
        footer: '> {{ payment_terms }}',
        continuation: '> {{ workspace }} · {{ number }}',
      ),
      data: {
        'workspace': 'COWORKONTI',
        'number': 'INV-2026-0041',
        'total': '100,00 €',
        'payment_terms': 'À 30 jours.',
      },
    );
    expect(report, isNotNull);
    expect(report!.continuation, isNotEmpty);
    expect((report.continuation.single as ReportMuted).text,
        'COWORKONTI · INV-2026-0041');
    // And it is NOT the header: the two must not be the same band.
    expect(report.header.single, isA<ReportHeading>());
  });

  test('the invoice template carries the continuation through an edit',
      () {
    const t = InvoicePdfTemplate(
      header: 'h',
      body: 'b',
      footer: 'f',
      continuation: 'c',
    );
    expect(t.invoiceBands.continuation, 'c');
    expect(
      InvoicePdfTemplate.fromJson(t.toJson().cast<String, dynamic>())
          .continuation,
      'c',
    );
    // Editing a reminder level must not drop the invoice's own strip.
    expect(t.withReminder(1, const ReportBands()).continuation, 'c');
  });
}
