// SPDX-License-Identifier: AGPL-3.0-or-later
// The editable VAT preparation report retains the persisted declaration's
// exact amounts and status; rendering neither files nor recalculates it.
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_declaration_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted tax bases and amounts reach the existing report engine', () {
    final declaration = VatDeclaration(
      id: 'declaration',
      workspaceId: 'workspace',
      periodStart: DateTime.utc(2026, 9),
      periodEnd: DateTime.utc(2026, 9, 30),
      status: 'draft',
      createdAt: DateTime.utc(2026, 10),
      currency: 'EUR',
      totalNetCents: 10000,
      totalVatCents: 2000,
      invoiceCount: 2,
      lines: const [
        VatDeclarationLine(
          percent: 20,
          grossCents: 12000,
          netCents: 10000,
          vatCents: 2000,
          invoiceCount: 2,
        ),
      ],
    );
    final data = vatDeclarationReportData(
      declaration: declaration,
      workspaceName: 'Example',
      vatId: 'EXAMPLE',
      countryCode: 'FR',
      disclaimer: 'Preparation only',
      statusLabel: 'Brouillon',
      money: (cents) => '$cents minor EUR',
      date: (date) => date.toIso8601String(),
      rate: (rate) => '$rate %',
    );
    expect(data['vat_period_net'], '10000 minor EUR');
    expect(data['vat_period_vat'], '2000 minor EUR');
    expect(data['declaration_status'], 'Brouillon');
    final report = renderReportBands(
      bands: defaultBandsForDoc('vat_declaration', AppLocalizationsFr()),
      data: data,
    )!;
    final rows = report.body.whereType<ReportTableRow>().toList();
    expect(
      rows.any(
        (row) =>
            row.cells.contains('10000 minor EUR') &&
            row.cells.contains('2000 minor EUR') &&
            row.cells.contains('2'),
      ),
      isTrue,
    );
    expect(
      report.footer.whereType<ReportMuted>().single.text,
      'Preparation only',
    );
    expect(declaration.status, 'draft');
  });

  test('the acquisition tax names itself beside the sales at its rate', () {
    final declaration = VatDeclaration(
      id: 'sep',
      workspaceId: 'workspace',
      periodStart: DateTime.utc(2026, 9),
      periodEnd: DateTime.utc(2026, 9, 30),
      status: 'prepared',
      createdAt: DateTime.utc(2026, 10),
      currency: 'CHF',
      totalNetCents: 1600000,
      totalVatCents: 138570,
      invoiceCount: 2,
      lines: const [
        VatDeclarationLine(
          percent: 8.1,
          category: 'S',
          grossCents: 1729600,
          netCents: 1600000,
          vatCents: 129600,
          invoiceCount: 2,
        ),
        VatDeclarationLine(
          percent: 8.1,
          category: vatAcquisitionCategory,
          grossCents: 1297200,
          netCents: 1200000,
          vatCents: 97200,
          invoiceCount: 2,
        ),
      ],
    );
    final data = vatDeclarationReportData(
      declaration: declaration,
      workspaceName: 'Example',
      vatId: 'CHE109322551',
      countryCode: 'CH',
      disclaimer: 'Preparation only',
      statusLabel: 'Prepared',
      money: (cents) => '$cents',
      date: (date) => date.toIso8601String(),
      rate: (rate) => '$rate %',
      lineNote: (line) => line.isAcquisition ? 'Acquisition tax' : '',
    );
    final rates = [
      for (final row in data['vat_rate_totals']! as List)
        (row as Map<String, Object?>)['rate'],
    ];
    expect(rates, ['8.1 %', 'Acquisition tax · 8.1 %']);
  });
}
