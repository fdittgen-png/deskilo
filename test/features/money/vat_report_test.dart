// SPDX-License-Identifier: 0BSD
//
// #878 — the VAT review as code: statutory mentions per country, the
// shape of a European VAT id, the readiness warning, and the VAT
// report built from frozen breakdowns with its CSV.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:deskilo/features/money/domain/vat_report.dart';
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String number, {
  required DateTime issuedAt,
  List<InvoiceVatTotal> vat = const [],
  List<InvoiceLine> lines = const [],
  DateTime? voidedAt,
  String? settledBy,
  String replaces = '',
}) =>
    Invoice(
      id: 'inv-$number',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: number,
      issuedAt: issuedAt,
      period: '2026-09',
      title: number,
      lines: lines,
      totalCents: lines.fold(0, (s, l) => s + l.amountCents),
      currency: 'EUR',
      memberName: 'Anne DUPONT',
      memberAddress: '',
      workspaceName: 'Demo',
      workspaceAddress: '',
      issuerName: '',
      signature: '',
      vatTotals: vat,
      voidedAt: voidedAt,
      settledByInvoiceId: settledBy,
      replacesNumber: replaces,
    );

void main() {
  group('statutory mentions', () {
    test('an exempt seller gets its member state\'s wording; a VAT-charging '
        'one nothing', () {
      expect(defaultExemptionMention('FR', VatRegime.exempt),
          contains('293 B'));
      expect(defaultExemptionMention('de', VatRegime.exempt),
          contains('§ 19 UStG'));
      expect(defaultExemptionMention('IT', VatRegime.exempt),
          contains('190/2014'));
      expect(defaultExemptionMention('PL', VatRegime.exempt),
          contains('2006/112/EC'));
      expect(defaultExemptionMention('FR', VatRegime.notSubject),
          contains('256 B'));
      expect(defaultExemptionMention('FR', VatRegime.vatRegistered), '');
    });

    test('the document prints it only when the owner wrote nothing', () {
      const exempt = Workspace(
        id: 'ws-1', name: 'Asso', countryCode: 'FR', currencyCode: 'EUR',
        timezone: 'Europe/Paris', inviteCode: 'CODE', vatRegime: 'exempt',
      );
      expect(legalMentionData(null, exempt)['exemption_reason'],
          contains('293 B'));
      expect(
        legalMentionData(null,
            exempt.copyWith(taxExemptionReason: 'Franchise en base'))
            ['exemption_reason'],
        'Franchise en base',
      );
      const registered = Workspace(
        id: 'ws-1', name: 'SARL', countryCode: 'FR', currencyCode: 'EUR',
        timezone: 'Europe/Paris', inviteCode: 'CODE',
        vatRegime: 'vat_registered',
      );
      expect(legalMentionData(null, registered)['exemption_reason'], '');
    });
  });

  group('VAT ids', () {
    test('the VIES shapes, punctuation ignored; unknown prefixes pass', () {
      expect(looksLikeEuVatId('FR 79 849 149 108'), isTrue);
      expect(looksLikeEuVatId('DE123456789'), isTrue);
      expect(looksLikeEuVatId('NL123456789B01'), isTrue);
      expect(looksLikeEuVatId('ATU12345678'), isTrue);
      expect(looksLikeEuVatId('DE12345678'), isFalse, reason: '8 digits');
      expect(looksLikeEuVatId('FR849149108'), isFalse, reason: 'no key');
      expect(looksLikeEuVatId('US123'), isTrue, reason: 'not in the table');
      expect(looksLikeEuVatId(''), isFalse);
    });

    test('a malformed buyer id is a WARNING, never a blocker', () {
      final readiness = checkEInvoiceReadiness(
        invoice: _invoice('INV-1',
            issuedAt: DateTime(2026, 9, 3),
            lines: const [InvoiceLine(kind: 'subscription', label: 'x', amountCents: 12000, vatPercent: 20)],
            vat: const [InvoiceVatTotal(percent: 20, category: 'S', grossCents: 12000, netCents: 10000, vatCents: 2000)]),
        seller: const InvoiceParty(
            name: 'SARL', street: 'r', city: 'Paris', postalCode: '75001',
            country: 'FR', vatId: 'FR12345678901', vatRegime: 'vat_registered'),
        buyer: const InvoiceParty(name: 'B', country: 'DE', vatId: 'DE1234'),
      );
      expect(readiness.gaps, contains(EInvoiceGap.buyerVatIdFormat));
      expect(EInvoiceGap.buyerVatIdFormat.isBlocking, isFalse);
    });
  });

  group('the report', () {
    const s20 = InvoiceVatTotal(
        percent: 20, category: 'S', grossCents: 12000, netCents: 10000, vatCents: 2000);
    const s55 = InvoiceVatTotal(
        percent: 5.5, category: 'S', grossCents: 1055, netCents: 1000, vatCents: 55);
    final invoices = [
      _invoice('INV-1', issuedAt: DateTime(2026, 9, 3), vat: [s20]),
      _invoice('INV-2', issuedAt: DateTime(2026, 9, 12), vat: [s20, s55]),
      _invoice('INV-3', issuedAt: DateTime(2026, 9, 20), vat: [s20],
          voidedAt: DateTime(2026, 9, 21)),
      _invoice('INV-4', issuedAt: DateTime(2026, 9, 25), vat: [s20],
          settledBy: 'inv-SET'),
      _invoice('INV-5', issuedAt: DateTime(2026, 10, 1), vat: [s20]),
      _invoice('INV-0', issuedAt: DateTime(2026, 9, 30, 23, 59),
          lines: const [InvoiceLine(kind: 'subscription', label: 'old', amountCents: 5000)],
          replaces: 'INV-OLD'),
    ];

    test('one position per document and rate, inside the period, voided and '
        'folded ones out; pre-0072 documents derive a zero-rated entry', () {
      final report = buildVatReport(invoices,
          start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30),
          zeroCategory: 'E');
      expect(report.positions.map((p) => '${p.number}@${p.percent}'),
          ['INV-1@20.0', 'INV-2@20.0', 'INV-2@5.5', 'INV-0@0.0']);
      expect(report.positions.last.category, 'E');
      expect(report.positions.last.reversesNumber, 'INV-OLD');
      expect(report.documentCount, 3);
      expect(report.rateTotals.map((t) => t.percent), [20.0, 5.5, 0.0]);
      expect(report.rateTotals.first.vatCents, 4000);
      expect(report.rateTotals.first.documentCount, 2);
      expect(report.vatCents, 4055);
      expect(report.grossCents, 12000 + 12000 + 1055 + 5000);
    });

    test('the CSV is one semicolon row per position, decimal comma', () {
      final report = buildVatReport(invoices.take(1),
          start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30),
          zeroCategory: 'E');
      final csv = vatReportCsv(report, currency: 'EUR');
      expect(csv.split('\n').first,
          'number;date;customer;rate;category;net;vat;gross;currency;reverses');
      expect(csv, contains('"INV-1";2026-09-03;"Anne DUPONT";20;S;100,00;20,00;120,00;EUR;""'));
    });

    test('the kind is registered and its default bands render the sample', () {
      expect(reportKindById('vat'), isNotNull);
      final report = renderReportBands(
          bands: defaultVatBands(null), data: sampleReportData(null));
      final body = report!.body.map(_text).join('\n');
      expect(body, contains('INV-2026-0007'));
      expect(body, contains('Totals per rate'));
      expect(body, contains('Period totals'));
    });
  });
}

String _text(ReportBlock block) => switch (block) {
      ReportHeading(:final text) => text,
      ReportSubheading(:final text) => text,
      ReportText(:final text) => text,
      ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      _ => '',
    };
