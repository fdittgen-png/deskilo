// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4269 -- the SAF-T ledger and the Sage audit trail write a document that
// charges something as a sale whatever the sign of its total, as the FEC and
// DATEV do: 120.00 charged at 20 % (net 100.00 and its VAT) and 240.00 of
// payments already received. The sale debits the customers 120.00 and credits
// revenue 100.00 and VAT 20.00; the two receipts are bank debits on the
// invoice's date; the 120.00 the member is paid back is money out; no
// credit note (SC) and no negative amount. Byte for byte as the goldens
// (`UPDATE_GOLDEN=1 flutter test test/features/money/mixed_document_saft_sage_test.dart`
// rewrites them when the document is MEANT to change); a real credit note
// is written as before.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

const _dir = 'test/features/money/goldens/mixed_document';
final _update = Platform.environment['UPDATE_GOLDEN'] == '1';

Invoice _mixed() => Invoice(
  id: 'id-F-1',
  workspaceId: 'ws',
  memberId: 'm1',
  number: 'F-1',
  issuedAt: DateTime(2026, 7, 15),
  period: '2026-07',
  title: 'T F-1',
  lines: const [
    InvoiceLine(kind: 'subscription', label: '100', amountCents: 12000, vatPercent: 20),
    InvoiceLine(kind: 'payment', label: 'virement', amountCents: -20000),
    InvoiceLine(kind: 'payment', label: 'carte', amountCents: -4000),
  ],
  totalCents: -12000,
  currency: 'EUR',
  memberName: 'Ana',
  memberAddress: 'a',
  workspaceName: 'w',
  workspaceAddress: 'a',
  issuerName: 'Flo',
  signature: 'f' * 64,
  sellerParty: seededCompany,
  buyerParty: const InvoiceParty(name: 'Ana', country: 'FR', memberNumber: 'C-0042'),
  vatTotals: const [
    InvoiceVatTotal(percent: 20, category: 'S', grossCents: 12000, netCents: 10000, vatCents: 2000),
  ],
);

Map<String, InvoiceMatch> _refund(Invoice i) => {
  i.id: InvoiceMatch(
    invoiceId: i.id,
    paidCents: -i.totalCents,
    resolution: 'refunded',
    matchedAt: DateTime(2026, 7, 20),
  ),
};

String _saft(Invoice i, Map<String, InvoiceMatch> matches) => buildSafTFile(
  SafTRequest(
    invoices: [i],
    matches: matches,
    company: seededCompany,
    currency: 'EUR',
    softwareVersion: '1',
    createdAt: DateTime(2027, 1, 5),
    lineText: (l) => l.label,
    ledgerAccounts: const SafTLedgerAccounts(customers: '411', revenue: '706', bank: '512', vat: '4457'),
    reference: ActiveTaxReference.current,
  ),
);

SageAuditTrail _sage(Invoice i, Map<String, InvoiceMatch> matches) => sageRowsOfInvoices(
  invoices: [i],
  matches: matches,
  accounts: SageAccounts(reference: ActiveTaxReference.current),
  customers: const SageCustomers(memberNumbers: {}, sellerCountry: 'FR'),
  baseCurrency: 'EUR',
  groupOf: (t) => ActiveTaxReference.current.groupOfRate('FR', t.percent, t.category),
);

void _golden(String name, String text) {
  final file = File('$_dir/$name');
  final bytes = utf8.encode(text);
  if (_update) file..createSync(recursive: true)..writeAsBytesSync(bytes);
  expect(file.existsSync(), isTrue, reason: '$name has no golden: UPDATE_GOLDEN=1 writes it');
  expect(bytes, file.readAsBytesSync(), reason: name);
}

/// The ledger's own amounts: the invoice documents carry amounts too.
int _sum(String xml, String tag) => RegExp('<$tag>([^<]*)</$tag>')
    .allMatches(_ledger(xml))
    .fold(0, (s, m) => s + (double.parse(m.group(1)!) * 100).round());

String _ledger(String xml) => xml.substring(
  xml.indexOf('<GeneralLedgerEntries>'),
  xml.indexOf('</GeneralLedgerEntries>'),
);

void main() {
  test('SAF-T writes the charges as a sale, the credits as receipts, the refund out', () {
    final i = _mixed();
    final xml = _saft(i, _refund(i));
    expect(RegExp('<TransactionID>([^<]*)</TransactionID>').allMatches(_ledger(xml)).map((m) => m.group(1)).toList(),
        unorderedEquals(['F-1', 'F-1-C1', 'F-1-C2', 'F-1-P']));
    expect(_sum(xml, 'DebitAmount'), _sum(xml, 'CreditAmount'));
    expect(xml.contains('-'), isTrue); // dates and ids carry hyphens
    expect(RegExp('<(Debit|Credit)Amount>-').hasMatch(_ledger(xml)), isFalse, reason: 'no negative amount');
    expect(xml.contains('Refund F-1'), isTrue);
    _golden('saft.xml', xml);
  });

  test('Sage writes an SI for the charges, receipts for the credits, an SP for the refund', () {
    final i = _mixed();
    final trail = _sage(i, _refund(i));
    expect(trail.blockers, isEmpty);
    final file = sageFile(trail.rows);
    final types = [for (final l in const LineSplitter().convert(file).skip(1)) l.split(',').first.replaceAll('"', '')];
    expect(types, unorderedEquals(['SI', 'SR', 'SR', 'SP']));
    expect(file.contains(',-'), isFalse, reason: 'no negative amount');
    _golden('sage.csv', file);
  });

  test('a credit note whose positions are all reversals is still an SC and a reversed SAF-T sale', () {
    final credit = _mixed().copyWith(
      lines: const [InvoiceLine(kind: 'adjustment', label: 'Avoir', amountCents: -12000, vatPercent: 20)],
      totalCents: -12000,
      vatTotals: const [],
    );
    final types = [for (final r in _sage(credit, const {}).rows) r.type];
    expect(types, ['SC']);
    final xml = _saft(credit, const {});
    expect(_sum(xml, 'DebitAmount'), _sum(xml, 'CreditAmount'));
    expect(xml.contains('<TransactionID>F-1</TransactionID>'), isTrue);
  });
}
