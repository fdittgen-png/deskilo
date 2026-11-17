// SPDX-License-Identifier: AGPL-3.0-or-later
// A DATEV request keeps its supplied chart, reference, clock and frozen buyer
// across another export. No live member registry is needed to name its Debitor.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/money/domain/datev.dart';
import '../../../lib/features/money/domain/datev_package.dart';

TaxReferenceSet _reference(String chart, String revenue, String bank) =>
    TaxReferenceSet([
      for (final entry in {
        'chart': chart,
        'revenue': revenue,
        'bank': bank,
        'expenses': '4900',
      }.entries)
        TaxReferenceRow(
          country: 'DE',
          key: 'coa/${entry.key}',
          validFrom: '2020-01-01',
          value: AccountMapValue(
            format: 'coa',
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

DatevPackageRequest _request(
  DatevAccounts accounts,
  DateTime Function(DateTime) dayOf,
) => DatevPackageRequest(
  request: DatevRequest(
    currency: 'EUR',
    invoices: [_invoice()],
    matches: const {},
    accounts: accounts,
    dayOf: dayOf,
    from: DateTime(2026),
    to: DateTime(2026, 12, 31),
    generatedAt: DateTime.utc(2027, 1, 5),
    consultantNumber: '1234567',
    clientNumber: '54321',
    detail: const DatevDetail(defaultCostCentre: 'Issuer A', voucherLinks: false),
  ),
  bookProfiles: const [],
  closed: (_, _) => false,
  memberSequence: NumberSequence.defaultsFor('member'),
  debtorBase: 10000,
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
