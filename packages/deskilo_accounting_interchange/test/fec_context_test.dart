// SPDX-License-Identifier: AGPL-3.0-or-later
// A document FEC and a posted FEC keep their supplied facts after another
// export; frozen billing identity needs no live member lookup, and an
// unsupported functional currency remains refused.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:test/test.dart';

TaxReferenceSet _reference(String revenue, String bank) => TaxReferenceSet([
  for (final entry in {
    'coa/customers': '411000',
    'coa/revenue': revenue,
    'coa/bank': bank,
    'coa/vat': '445710',
    'coa/expenses': '606000',
    'fec/vat_pending': '445740',
    'fec/write_off': '654000',
  }.entries)
    TaxReferenceRow(
      country: 'FR',
      key: entry.key,
      validFrom: '2020-01-01',
      value: AccountMapValue(
        format: entry.key.split('/').first,
        role: entry.key.split('/').last,
        account: entry.value,
      ),
      source: 'held test chart',
      confirmed: true,
    ),
]);

FecJournals _journals(String suffix) => FecJournals(
  sales: FecJournal(code: 'VE$suffix', label: 'Sales $suffix'),
  bank: FecJournal(code: 'BQ$suffix', label: 'Bank $suffix'),
  purchases: FecJournal(code: 'AC$suffix', label: 'Purchases $suffix'),
  misc: FecJournal(code: 'OD$suffix', label: 'Misc $suffix'),
);

Invoice _invoice() => Invoice(
  id: 'invoice-a',
  workspaceId: 'issuer-a',
  memberId: 'departed-subject',
  number: 'INV-A',
  issuedAt: DateTime.utc(2026, 3, 1, 0, 30),
  period: '2026-03',
  title: 'Issued service',
  lines: const [
    InvoiceLine(kind: 'service', label: 'Service', amountCents: 10000),
  ],
  totalCents: 10000,
  currency: 'EUR',
  memberName: 'Frozen customer',
  memberAddress: 'Frozen street',
  workspaceName: 'Issuer A',
  workspaceAddress: 'Issuer street',
  issuerName: 'Issuer',
  signature: 'held',
  buyerParty: const InvoiceParty(
    name: 'Frozen customer',
    memberNumber: 'M-0042',
    street: 'Frozen street',
    country: 'FR',
  ),
  sellerParty: const InvoiceParty(name: 'Issuer A', country: 'FR'),
);

FecRequest _request(
  TaxReferenceSet reference,
  FecJournals journals,
  DateTime Function(DateTime) dayOf,
) => FecRequest(
  currency: 'EUR',
  invoices: [_invoice()],
  matches: {
    'invoice-a': InvoiceMatch(
      invoiceId: 'invoice-a',
      paidCents: 4000,
      resolution: 'partial',
      matchedAt: DateTime(2026, 5),
      writeoffAt: DateTime.utc(2026, 6, 1, 0, 30),
    ),
  },
  company: const InvoiceParty(name: 'Issuer A', country: 'FR'),
  accounts: FecAccounts(
    reference: reference,
    chartCountry: 'FR',
    journals: journals,
  ),
  lineText: (line) => line.label,
  reference: reference,
  dayOf: dayOf,
  ledger: [
    LedgerEntry(
      id: 'expense-a',
      memberId: 'departed-subject',
      kind: LedgerKind.credit,
      category: LedgerCategory.expense,
      amountCents: 2500,
      description: 'Expense',
      period: '2026-04',
      createdAt: DateTime.utc(2026, 4, 10),
    ),
  ],
);

List<Posting> _postings(String revenue) => [
  Posting(
    journal: PostingJournal.sales,
    date: DateTime(2026, 3),
    kind: PostingKind.invoice,
    documentId: 'invoice-a',
    documentNumber: 'INV-A',
    lines: [
      PostingLine(
        role: BookRole.customers,
        accountCode: '411000',
        debit: AccountingAmount('EUR', 10000),
        credit: AccountingAmount('EUR', 0),
      ),
      PostingLine(
        role: BookRole.revenue,
        accountCode: revenue,
        debit: AccountingAmount('EUR', 0),
        credit: AccountingAmount('EUR', 10000),
      ),
    ],
  ),
];

void main() {
  test(
    'document A retains chart, clock, payment and frozen subject after B',
    () {
      final a = _request(
        _reference('706001', '512001'),
        _journals('A'),
        (d) => DateTime(d.year, d.month, d.day),
      );
      final b = _request(
        _reference('706002', '512002'),
        _journals('B'),
        (d) => d.subtract(const Duration(hours: 2)),
      );
      final firstA = buildFecFile(a), other = buildFecFile(b);
      expect(buildFecFile(a), firstA);
      expect(other, isNot(firstA));
      expect(firstA, contains('706001'));
      expect(other, contains('706002'));
      expect(firstA, contains('20260301'));
      expect(firstA, contains('20260601'));
      expect(other, contains('20260531'));
      expect(firstA, contains('departed-subject'));
      expect(firstA, contains('Frozen customer'));
      expect(firstA, contains('BQA'));
      expect(firstA, contains('ACA'));
    },
  );

  test('posted A retains its journals, chart and frozen party after B', () {
    final a = _postings('706001'), b = _postings('706002');
    final parties = {
      'invoice-a': const PostingParty(
        kind: 'customer',
        number: 'M-0042',
        name: 'Frozen customer',
      ),
    };
    final firstA = buildFecFromPostings(
      a,
      accountNames: const {},
      parties: parties,
      journals: _journals('A'),
      currency: (code: 'EUR', rates: <String, FxRate>{}),
    );
    final other = buildFecFromPostings(
      b,
      accountNames: const {},
      parties: parties,
      journals: _journals('B'),
      currency: (code: 'EUR', rates: <String, FxRate>{}),
    );
    final secondA = buildFecFromPostings(
      a,
      accountNames: const {},
      parties: parties,
      journals: _journals('A'),
      currency: (code: 'EUR', rates: <String, FxRate>{}),
    );
    expect(firstA.blockers, isEmpty);
    expect(other.blockers, isEmpty);
    expect(secondA.blockers, isEmpty);
    expect(secondA.file, firstA.file);
    expect(other.file, isNot(firstA.file));
    expect(firstA.file, contains('Frozen customer'));
    expect(firstA.file, contains('411M0042'));
    final refused = buildFecFromPostings(
      a,
      accountNames: const {},
      parties: parties,
      journals: _journals('A'),
      currency: (code: 'USD', rates: <String, FxRate>{}),
    );
    expect(refused.file, isEmpty);
    expect(refused.blockers.single.block, FecBlock.currency);
  });
}
