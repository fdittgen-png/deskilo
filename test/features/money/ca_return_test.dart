// SPDX-License-Identifier: AGPL-3.0-or-later
// test-inventory: pure rules — the invariant is that GST34 holds the federal taxes only and FPZ-500 the QST
//
// #2361 — a Quebec registrant's return: CAD 1 000.00 of sales at 14.975 %
// plus CAD 100.00 at 5 %, and an expense with 14.975 % input tax. The
// server's split (migration 0425, pgTAP 182) is read from the line; a line
// without it is split here with the same arithmetic.
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_ca.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _line(
  double percent,
  int net,
  int vat, {
  bool input = false,
  List<Map<String, Object?>>? parts,
}) => {
  'percent': percent,
  'category': 'S',
  'gross_cents': net + vat,
  'net_cents': net,
  'vat_cents': vat,
  'invoice_count': 1,
  if (input) 'direction': 'input',
  'components': ?parts,
};

Map<String, Object?> _c(String scheme, double p, int base, int tax) => {
  'scheme': scheme,
  'authority': scheme == 'QST' ? 'CA-QC' : 'CA',
  'percent': p,
  'base_cents': base,
  'tax_cents': tax,
};

VatDeclaration _declaration({bool split = true}) => VatDeclaration(
  id: 'd1',
  workspaceId: 'w1',
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 9, 30),
  status: 'prepared',
  lines: [
    for (final l in [
      _line(
        14.975,
        100000,
        14975,
        parts: split
            ? [_c('GST', 5, 100000, 5000), _c('QST', 9.975, 100000, 9975)]
            : null,
      ),
      _line(5, 10000, 500, parts: split ? [_c('GST', 5, 10000, 500)] : null),
      _line(
        14.975,
        50000,
        7487,
        input: true,
        parts: split
            ? [_c('GST', 5, 50000, 2500), _c('QST', 9.975, 50000, 4987)]
            : null,
      ),
    ])
      VatDeclarationLine.fromJson(l),
  ],
  totalNetCents: 110000,
  totalVatCents: 15475,
  currency: 'CAD',
  invoiceCount: 2,
  createdAt: DateTime(2026, 10),
);

Map<String, int> _tax(List<VatFormBox> boxes) => {
  for (final b in boxes) b.code: b.vatCents,
};

void main() {
  for (final split in [true, false]) {
    test('GST34 holds GST only and FPZ-500 the QST (server split: $split)', () {
      final d = _declaration(split: split);
      final gst = _tax(vatFormBoxes('CA', d.lines, periodEnd: d.periodEnd));
      expect(gst['103'], 5500, reason: 'GST on both sales lines, not the QST');
      expect(gst['106'], 2500);
      expect(gst['109'], 3000);
      final qst = _tax(vatQstFormBoxes(d.lines));
      expect(qst['203'], 9975);
      expect(qst['205'], 9975);
      expect(qst['206'], 4987);
      expect(qst['209'], 4988);
    });
  }

  test('the base of line 101 is the whole sales, in whole dollars', () {
    final d = _declaration();
    final box = vatFormBoxes(
      'CA',
      d.lines,
      periodEnd: d.periodEnd,
    ).firstWhere((b) => b.code == '101');
    expect(box.netCents, 110000);
  });

  test('no QST charged or claimed: no FPZ-500 part', () {
    final lines = [VatDeclarationLine.fromJson(_line(13, 10000, 1300))];
    expect(vatQstFormBoxes(lines), isEmpty);
  });

  test('the file: GST34 lines then FPZ-500, the business number formatted', () {
    final csv = gstQstReturnCsv(
      declaration: _declaration(),
      businessNumber: '123456789rt0001',
    );
    final rows = csv.trim().split('\r\n');
    expect(rows.first, startsWith('"return","business_number"'));
    expect(rows.where((r) => r.startsWith('"GST34"')), isNotEmpty);
    expect(rows.where((r) => r.startsWith('"FPZ-500"')).length, greaterThan(2));
    expect(csv, contains('"123456789 RT0001"'));
    expect(csv, contains('"209","Net QST",,49.88'));
    expect(
      () => gstQstReturnCsv(
        declaration: _declaration(),
        businessNumber: '123456789',
      ),
      throwsA(isA<VatFilingFileException>()),
    );
  });

  test('a Canadian space has a file; the filename carries the period', () {
    final file = vatFilingFile(
      declaration: _declaration(),
      party: const VatFilingParty(
        countryCode: 'CA',
        name: 'Espace',
        street: '',
        postalCode: '',
        city: '',
        vatId: '123456789 RT0001',
        legalId: '1234567890 TQ0001',
      ),
      now: DateTime(2026, 10, 13),
    );
    expect(file.fileName, 'gst-hst-qst-return-2026-07-01.csv');
  });
}
