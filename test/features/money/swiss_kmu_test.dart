// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2360 — the Swiss booking journal: the KMU accounts, one row per rate,
// the Ziffer of the MWST return on each row, a credit note swapped and
// positive, a receipt without VAT, a BOM, CRLF.
import 'package:deskilo/features/money/domain/coa_preview.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/swiss_kmu.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String id,
  String number,
  List<InvoiceVatTotal> totals, {
  DateTime? voidedAt,
}) {
  final gross = totals.fold(0, (s, t) => s + t.grossCents);
  return Invoice(
    id: id,
    workspaceId: 'ws',
    memberId: 'm-$id',
    number: number,
    issuedAt: DateTime.utc(2026, 9, 30),
    title: 'September',
    lines: [InvoiceLine(label: 'Desk', amountCents: gross)],
    totalCents: gross,
    currency: 'CHF',
    memberName: 'Ana',
    memberAddress: '',
    workspaceName: 'Cowork AG',
    workspaceAddress: '',
    issuerName: 'Cowork AG',
    signature: '',
    voidedAt: voidedAt,
    vatTotals: totals,
  );
}

const _normal = InvoiceVatTotal(
  percent: 8.1,
  category: 'S',
  grossCents: 10810,
  netCents: 10000,
  vatCents: 810,
);
const _exempt = InvoiceVatTotal(
  percent: 0,
  category: 'E',
  grossCents: 5000,
  netCents: 5000,
  vatCents: 0,
);

void main() {
  test('Ziffern: the rate lines of 2024 and the deductions', () {
    expect(swissZifferOf(_normal), '303');
    expect(swissZifferOf(_exempt), '230');
    expect(
      swissZifferOf(
        const InvoiceVatTotal(
          percent: 2.6,
          category: 'S',
          grossCents: 0,
          netCents: 0,
          vatCents: 0,
        ),
      ),
      '313',
    );
    expect(
      swissZifferOf(
        const InvoiceVatTotal(
          percent: 3.8,
          category: 'S',
          grossCents: 0,
          netCents: 0,
          vatCents: 0,
        ),
      ),
      '343',
    );
    expect(
      swissZifferOf(
        const InvoiceVatTotal(
          percent: 0,
          category: 'Z',
          grossCents: 0,
          netCents: 0,
          vatCents: 0,
        ),
      ),
      '220',
    );
  });

  test('the journal: one row per rate, accounts, Ziffer, a receipt', () {
    final i1 = _invoice('i1', 'INV-1', [_normal, _exempt]);
    final credit = _invoice('i2', 'INV-2', [
      const InvoiceVatTotal(
        percent: 8.1,
        category: 'S',
        grossCents: -1081,
        netCents: -1000,
        vatCents: -81,
      ),
    ]);
    final voided = _invoice('i3', 'INV-3', [
      _normal,
    ], voidedAt: DateTime.utc(2026, 10));
    final text = buildSwissKmuFile(
      invoices: [i1, credit, voided],
      matches: {
        'i1': InvoiceMatch(
          invoiceId: 'i1',
          paidCents: 15810,
          resolution: 'exact',
          matchedAt: DateTime.utc(2026, 10, 2),
        ),
      },
      accounts: const SwissKmuAccounts(),
      customerRef: (i) => i.memberName,
    );
    expect(text.startsWith('\u{FEFF}Datum;Beleg;'), isTrue);
    final rows = text.substring(1).trimRight().split('\r\n');
    expect(rows, [
      'Datum;Beleg;Text;Soll;Haben;Betrag;Waehrung;MWST-Satz;MWST-Betrag;MWST-Konto;Ziffer;Kunde',
      '30.09.2026;"INV-1";"September";1100;3400;108.10;CHF;8.1;8.10;2200;303;"Ana"',
      '30.09.2026;"INV-1";"September";1100;3402;50.00;CHF;;0.00;;230;"Ana"',
      '02.10.2026;"INV-1";"Zahlung INV-1";1020;1100;158.10;CHF;;;;;"Ana"',
      '30.09.2026;"INV-2";"September";3400;1100;10.81;CHF;8.1;0.81;2200;303;"Ana"',
    ]);
  });

  test('the KMU chart keeps the turnover apart and names 2201', () {
    final chart = coaChartFor(
      countryCode: 'CH',
      regime: VatRegime.vatRegistered,
      noteFor: (_) => 'n',
    );
    expect(chart.accounts.map((a) => a.number), [
      '1100',
      '3400',
      '3401',
      '3402',
      '1020',
      '2200',
      '2201',
      '6500',
    ]);
    expect(chart.numberFor(CoaAccountRole.revenue), '3400');
  });
}
