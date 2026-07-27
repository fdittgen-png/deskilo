// SPDX-License-Identifier: 0BSD
//
// FEC (0075) — Fichier des Écritures Comptables, the file French law
// requires in an audit (art. L47 A-I du LPF, arrêté du 29 juillet 2013).
// Not XML: a tab-separated flat file of accounting ENTRIES, which is why —
// unlike SAF-T — it cannot avoid account numbers.
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';

const _company = InvoiceParty(
  name: 'pezenas1',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812 345 678',
);

Invoice _invoice({
  String number = 'INV-2026-0001',
  DateTime? issuedAt,
  int subscription = 25000,
  int netted = 0,
  DateTime? voidedAt,
}) =>
    Invoice(
      id: 'inv-$number',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: number,
      issuedAt: issuedAt ?? DateTime(2026, 7, 2),
      period: '2026-06',
      title: '2026-06',
      lines: [
        InvoiceLine(
            kind: 'subscription', label: '100', amountCents: subscription),
        if (netted > 0)
          InvoiceLine(
              kind: 'payment', label: 'Virement', amountCents: -netted),
      ],
      totalCents: subscription - netted,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue du Test',
      workspaceName: 'pezenas1',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      voidedAt: voidedAt,
      voidedByName: voidedAt == null ? '' : 'Flo',
      sellerParty: _company,
    );

/// The file as rows of columns — what a DGFiP reader positions by.
List<Map<String, String>> _rows({
  List<Invoice>? invoices,
  Map<String, InvoiceMatch> matches = const {},
  FecAccounts accounts = const FecAccounts(),
}) {
  final file = buildFecFile(
    invoices: invoices ?? [_invoice()],
    matches: matches,
    company: _company,
    accounts: accounts,
    lineText: (line) => invoiceLineText(null, line),
  );
  final lines = file.split('\r\n');
  final header = lines.first.split('\t');
  return [
    for (final line in lines.skip(1))
      Map.fromIterables(header, line.split('\t')),
  ];
}

void main() {
  test('the first line is the 18 mandated columns, in the mandated order',
      () {
    final file = buildFecFile(
      invoices: [_invoice()],
      matches: const {},
      company: _company,
      accounts: const FecAccounts(),
      lineText: (line) => invoiceLineText(null, line),
    );

    expect(file.split('\r\n').first.split('\t'), fecColumns);
    expect(fecColumns, hasLength(18));
    expect(fecColumns.first, 'JournalCode');
    expect(fecColumns[3], 'EcritureDate');
    expect(fecColumns[11], 'Debit');
    expect(fecColumns.last, 'Idevise');
  });

  test('the file NAME is <SIREN>FEC<yyyymmdd>.txt — not a suggestion', () {
    expect(
      fecFileName('812 345 678', DateTime(2026, 12, 31)),
      '812345678FEC20261231.txt',
      reason: 'the SIREN keeps only its digits',
    );
  });

  test('an invoice books the receivable against the revenue, balanced', () {
    final rows = _rows();

    expect(rows, hasLength(2));
    expect(rows.first['JournalCode'], 'VE');
    expect(rows.first['EcritureNum'], 'VE0001');
    expect(rows.first['EcritureDate'], '20260702');
    expect(rows.first['CompteNum'], '411000');
    expect(rows.first['CompAuxNum'], 'member-1',
        reason: 'the customer sub-account is the member, unambiguously');
    expect(rows.first['CompAuxLib'], 'Ana Martin');
    expect(rows.first['PieceRef'], 'INV-2026-0001');
    expect(rows.first['Debit'], '250,00',
        reason: 'the comma is the decimal separator the arrêté fixes');
    expect(rows.first['Credit'], '0,00');
    expect(rows.last['CompteNum'], '706000');
    expect(rows.last['Credit'], '250,00');
    // Double entry: the two sides of the same entry number cancel.
    expect(rows.first['EcritureNum'], rows.last['EcritureNum']);
  });

  test('the accounts are the caller\'s, not the app\'s opinion', () {
    final rows = _rows(
      accounts: const FecAccounts(
        customers: '411CLI',
        revenue: '70600',
        bank: '51200',
      ),
    );

    expect(rows.first['CompteNum'], '411CLI');
    expect(rows.last['CompteNum'], '70600');
  });

  test('a credit the invoice NETTED is booked as cash, lettered with the '
      'invoice', () {
    final rows = _rows(invoices: [_invoice(netted: 20000)]);

    expect(rows, hasLength(4));
    final cash = rows.where((r) => r['JournalCode'] == 'BQ').toList();
    expect(cash, hasLength(2));
    expect(cash.first['CompteNum'], '512000');
    expect(cash.first['Debit'], '200,00');
    expect(cash.last['CompteNum'], '411000');
    expect(cash.last['Credit'], '200,00');
    expect(cash.first['EcritureLet'], 'INV-2026-0001',
        reason: 'the lettering ties the cash back to its invoice');
    // The receivable stays GROSS: revenue is what was invoiced, not what
    // was left to pay.
    expect(rows.first['Debit'], '250,00');
  });

  test('the payment that MATCHED the invoice is booked on its own date', () {
    final invoice = _invoice();
    final rows = _rows(invoices: [invoice], matches: {
      invoice.id: InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 25000,
        resolution: 'exact',
        matchedAt: DateTime(2026, 8, 6),
        byName: 'Flo',
      ),
    });

    final cash = rows.where((r) => r['JournalCode'] == 'BQ').toList();
    expect(cash, hasLength(2));
    expect(cash.first['EcritureDate'], '20260806',
        reason: 'cash is dated when it moved, not when it was invoiced');
    expect(cash.first['PieceDate'], '20260702',
        reason: 'the piece is still the invoice');
    expect(cash.first['Debit'], '250,00');
  });

  test('a match on an invoice with NOTHING left to pay is not booked twice',
      () {
    // The month's payment already covered it: solde 0.
    final invoice = _invoice(netted: 25000);
    final rows = _rows(invoices: [invoice], matches: {
      invoice.id: InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 25000,
        resolution: 'exact',
        matchedAt: DateTime(2026, 8, 6),
      ),
    });

    expect(rows.where((r) => r['JournalCode'] == 'BQ'), hasLength(2),
        reason: 'the netted credit only — booking the match too would '
            'inflate the bank by the same money');
  });

  test('a PENDING match is not cash yet', () {
    final invoice = _invoice();
    final rows = _rows(invoices: [invoice], matches: {
      invoice.id: InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 25000,
        resolution: 'exact',
        status: 'pending',
        matchedAt: DateTime(2026, 8, 6),
      ),
    });

    expect(rows.where((r) => r['JournalCode'] == 'BQ'), isEmpty);
  });

  test('a CANCELLED invoice is absent — it was never booked', () {
    final rows = _rows(invoices: [
      _invoice(number: 'INV-1'),
      _invoice(number: 'INV-2', voidedAt: DateTime(2026, 7, 3)),
    ]);

    expect(rows.map((r) => r['PieceRef']).toSet(), {'INV-1'});
  });

  test('entries are numbered per journal and ordered oldest first', () {
    final rows = _rows(invoices: [
      _invoice(number: 'INV-LATE', issuedAt: DateTime(2026, 9, 1)),
      _invoice(number: 'INV-EARLY', issuedAt: DateTime(2026, 6, 1)),
    ]);

    expect(rows.first['PieceRef'], 'INV-EARLY');
    expect(rows.first['EcritureNum'], 'VE0001');
    expect(rows.last['EcritureNum'], 'VE0002');
  });

  test('a tab inside a label can never shift a column', () {
    final rows = _rows(invoices: [
      _invoice().copyWith(memberName: 'Ana\tMartin\nDupont'),
    ]);

    expect(rows.first['CompAuxLib'], 'Ana Martin Dupont');
    expect(rows.first.length, 18, reason: 'still exactly 18 columns');
  });
}
