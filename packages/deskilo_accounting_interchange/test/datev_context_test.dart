// SPDX-License-Identifier: AGPL-3.0-or-later
// A DATEV request keeps its supplied chart, reference, clock and frozen buyer
// across another export. No live member registry is needed to name its Debitor.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:test/test.dart';

TaxReferenceSet _reference(String chart, String revenue, String bank) =>
    TaxReferenceSet([
      for (final entry in {
        'chart': chart,
        'revenue': revenue,
        'bank': bank,
        'expenses': '4900',
        'write_off': '2400',
      }.entries)
        TaxReferenceRow(
          country: 'DE',
          key: '${entry.key == 'write_off' ? 'datev' : 'coa'}/${entry.key}',
          validFrom: '2020-01-01',
          value: AccountMapValue(
            format: entry.key == 'write_off' ? 'datev' : 'coa',
            role: entry.key,
            account: entry.value,
          ),
          source: 'held test chart',
          confirmed: true,
        ),
    ]);

Invoice _invoice() => Invoice(
  id: 'invoice-a',
  workspaceId: 'issuer-a',
  memberId: 'billing-subject-a',
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
    postalCode: '10115',
    city: 'Berlin',
    country: 'DE',
  ),
);

Posting _purchase() => Posting(
  journal: PostingJournal.purchases,
  date: DateTime(2026, 4, 10),
  kind: PostingKind.supplierBill,
  documentId: 'supplier-bill',
  documentNumber: 'BILL-7',
  lines: [
    PostingLine(
      role: BookRole.expenses,
      accountCode: '4980',
      debit: AccountingAmount('EUR', 2500),
      credit: AccountingAmount('EUR', 0),
    ),
    PostingLine(
      role: BookRole.suppliers,
      accountCode: '1600',
      debit: AccountingAmount('EUR', 0),
      credit: AccountingAmount('EUR', 2500),
    ),
  ],
);

const _supplier = PostingParty(
  kind: 'supplier',
  number: '7',
  name: 'Frozen supplier',
);

DatevPackageRequest _request(
  DatevAccounts accounts,
  DateTime Function(DateTime) dayOf,
) => DatevPackageRequest(
  request: DatevRequest(
    currency: 'EUR',
    invoices: [_invoice()],
    matches: {
      'invoice-a': InvoiceMatch(
        invoiceId: 'invoice-a',
        paidCents: 4000,
        resolution: 'partial',
        matchedAt: DateTime(2026, 5, 1),
      ),
    },
    accounts: accounts,
    dayOf: dayOf,
    from: DateTime(2026),
    to: DateTime(2026, 12, 31),
    generatedAt: DateTime.utc(2027, 1, 5),
    consultantNumber: '1234567',
    clientNumber: '54321',
    detail: const DatevDetail(
      defaultCostCentre: 'Issuer A',
      voucherLinks: false,
    ),
  ),
  bookProfiles: const [],
  closed: (_, _) => false,
  memberSequence: NumberSequence.defaultsFor('member'),
  debtorBase: 10000,
  purchases: DatevPurchases(
    creditorBase: 70000,
    postings: [_purchase()],
    parties: const {'supplier-bill': _supplier},
  ),
);

void main() {
  test(
    'export A keeps its bytes after B uses another chart, reference and clock',
    () {
      final a = _request(
        DatevAccounts(
          reference: _reference('SKR03', '8400', '1200'),
          chartCountry: 'DE',
        ),
        (d) => DateTime(d.year, d.month, d.day),
      );
      final b = _request(
        DatevAccounts(
          reference: _reference('SKR04', '4400', '1800'),
          chartCountry: 'DE',
        ),
        (d) => d.subtract(const Duration(hours: 2)),
      );
      final firstA = buildDatevPackage(a);
      final other = buildDatevPackage(b);
      final secondA = buildDatevPackage(a);
      expect(firstA.problems, isEmpty);
      expect(other.problems, isEmpty);
      expect(secondA.problems, isEmpty);
      expect(firstA.files, isNotEmpty);
      expect(secondA.files, firstA.files);
      expect(other.files, isNot(firstA.files));
      expect(
        firstA.files.keys,
        contains('EXTF_Buchungsstapel_202603_sales.csv'),
      );
      expect(
        other.files.keys,
        contains('EXTF_Buchungsstapel_202602_sales.csv'),
      );
      expect(firstA.files.values.join(), contains('8400'));
      expect(other.files.values.join(), contains('4400'));
      expect(firstA.files.values.join(), contains('Frozen supplier'));
      expect(firstA.files.values.join(), contains('70007'));
      expect(
        firstA.files.keys,
        contains('EXTF_Buchungsstapel_202605_bank.csv'),
      );
      expect(
        firstA.files.keys,
        contains('EXTF_Buchungsstapel_202604_purchases.csv'),
      );
    },
  );

  test(
    'the issued billing subject and buyer name export without a live member',
    () {
      final result = buildDatevPackage(
        _request(
          DatevAccounts(
            reference: _reference('SKR03', '8400', '1200'),
            chartCountry: 'DE',
          ),
          (d) => DateTime(d.year, d.month, d.day),
        ),
      );
      expect(result.problems, isEmpty);
      final text = result.files.values.join();
      expect(text, contains('10042'));
      expect(text, contains('Frozen customer'));
      expect(text, contains('Frozen street'));
    },
  );
}
