// SPDX-License-Identifier: 0BSD
//
// #946 — a document names the site it concerns: the seller party and
// the attendance rows read the site from the frozen snapshot, the
// placeholders reach the template, and the SQL twin patches the five
// anchors of create_invoice.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:flutter_test/flutter_test.dart';


String _flat(List<ReportBlock> blocks) => blocks
    .map((b) => b is ReportText ? b.text : b is ReportMuted ? b.text : '')
    .join('\n');

void main() {
  test('the seller party carries its site; an older snapshot reads as the '
      'default site', () {
    final annexe = InvoiceParty.fromSnapshot({
      'name': 'COWORKONTI', 'street': '12 quai du Port', 'postal_code': '34300',
      'city': 'Agde', 'legal_id': '10825191900024', 'site': 'Annexe Agde', 'site_default': false,
    });
    expect((annexe.site, annexe.siteDefault, annexe.legalId), ('Annexe Agde', false, '10825191900024'));
    final old = InvoiceParty.fromSnapshot(const {'name': 'COWORKONTI'});
    expect((old.site, old.siteDefault), ('', true));
  });

  test('an attendance row names its site', () {
    const row = InvoiceAttendance(
      startsAt: '2026-09-03T08:00', endsAt: '2026-09-03T17:00',
      status: 'completed', space: 'Table 1 · Place 2', site: 'Annexe Agde',
    );
    expect(row.site, 'Annexe Agde');
    expect(const InvoiceAttendance(startsAt: '', endsAt: '').site, '');
  });

  test('the placeholders exist and render: the site line prints only when '
      'the document is not at the default site', () {
    expect(InvoicePdfTemplate.placeholders, containsAll(['site_name', 'site_address', 'usage_sites']));
    const bands = ReportBands(
      header: '{{ workspace }}\n{% if site_name != "" %}> {{ site_name }} — {{ site_address }}{% endif %}',
      body: '{% if usage_sites != "" %}Also at {{ usage_sites }}{% endif %}',
    );
    final at = renderInvoiceReport(template: withBands(InvoicePdfTemplate.empty, fixedReportKinds.first, bands), data: const {
      'workspace': 'COWORKONTI', 'site_name': 'Annexe Agde', 'site_address': '12 quai du Port, 34300 Agde',
      'usage_sites': 'Siège', 'lines': <Object?>[], 'vat': <Object?>[],
    });
    expect(_flat(at!.header), contains('Annexe Agde — 12 quai du Port, 34300 Agde'));
    expect(_flat(at.body), contains('Also at Siège'));
    final home = renderInvoiceReport(template: withBands(InvoicePdfTemplate.empty, fixedReportKinds.first, bands), data: const {
      'workspace': 'COWORKONTI', 'site_name': '', 'site_address': '', 'usage_sites': '',
      'lines': <Object?>[], 'vat': <Object?>[],
    });
    expect(_flat(home!.header), isNot(contains('—')));
    expect(_flat(home.body), isNot(contains('Also at')));
  });

  test('the SQL twin (0169) patches five asserted anchors and walks a '
      'reservation up to its site', () {
    final sql = File('supabase/migrations/0169_site_documents.sql').readAsStringSync();
    for (final a in ['A', 'B', 'C', 'D', 'E']) {
      expect(sql, contains("raise exception '0169: anchor $a missing'"));
    }
    expect(sql, contains('v_site := public.document_site_for_member(v_subject.id);'));
    expect(sql, contains("''site'', coalesce(v_site.name, '''')"));
    expect(sql, contains("''site'', coalesce((public.reservation_site(r)).name, '''')"));
    expect(sql, contains('create or replace function public.reservation_site(r public.reservations)'));
  });
}
