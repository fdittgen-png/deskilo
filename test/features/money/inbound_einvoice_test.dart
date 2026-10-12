// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the supplier inbox reads UBL and CII. The round trips parse what
// our own generators write; the hand-written documents pin the figures,
// the credit note and every refusal.
import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/inbound_einvoice.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'RE-2026-0042',
  issuedAt: DateTime(2026, 9, 30),
  period: '2026-09',
  title: '2026-09',
  lines: const [
    InvoiceLine(
      kind: 'subscription',
      label: '50',
      amountCents: 11900,
      vatPercent: 19,
      vatCategory: 'S',
    ),
  ],
  vatTotals: const [
    InvoiceVatTotal(
      percent: 19,
      category: 'S',
      grossCents: 11900,
      netCents: 10000,
      vatCents: 1900,
    ),
  ],
  totalCents: 11900,
  currency: 'EUR',
  memberName: 'B',
  memberAddress: '',
  workspaceName: 'S',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
);

const _seller = InvoiceParty(
  name: 'Test Space GmbH',
  street: 'Hauptstraße 1',
  city: 'Berlin',
  postalCode: '10115',
  country: 'DE',
  vatId: 'DE123456789',
  vatRegime: 'vat_registered',
  endpointId: 'billing@test.example',
  endpointScheme: 'EM',
);

const _buyer = InvoiceParty(
  name: 'Buyer',
  city: 'Berlin',
  postalCode: '10178',
  country: 'DE',
);

String _lineText(InvoiceLine l) => invoiceLineText(const ReportStrings(), l);

void _expectOurInvoice(InboundEInvoice p, InboundEInvoiceSyntax syntax) {
  expect(p.syntax, syntax);
  expect(p.number, 'RE-2026-0042');
  expect(p.issueDate, '2026-09-30');
  expect(p.dueDate, '2026-10-30');
  expect(p.currency, 'EUR');
  expect(p.supplierName, 'Test Space GmbH');
  expect(p.supplierVatId, 'DE123456789');
  expect(p.netCents, 10000);
  expect(p.taxCents, 1900);
  expect(p.grossCents, 11900);
  expect(p.documentType, '380');
  expect(p.isCreditNote, isFalse);
}

void main() {
  test('reads the UBL our generator writes', () {
    final xml = buildInvoiceUbl(
      invoice: _invoice,
      seller: _seller,
      buyer: _buyer,
      lineText: _lineText,
      profile: UblProfile.peppolBis,
      dueDate: DateTime(2026, 10, 30),
      paymentTerms: '30 days net',
    );
    final p = parseInboundEInvoice(xml);
    _expectOurInvoice(p, InboundEInvoiceSyntax.ubl);
    expect(p.supplierEndpoint, 'billing@test.example');
  });

  test('reads the CII our generator writes', () {
    final xml = buildInvoiceCii(
      invoice: _invoice,
      seller: _seller,
      buyer: _buyer,
      lineText: _lineText,
      dueDate: DateTime(2026, 10, 30),
      paymentTerms: '30 days net',
    );
    _expectOurInvoice(parseInboundEInvoice(xml), InboundEInvoiceSyntax.cii);
  });

  test('a UBL credit note is 381 and keeps its figures', () {
    const xml = '''<?xml version="1.0"?>
<CreditNote xmlns="urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2"
  xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
  xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:ID>AV-7</cbc:ID><cbc:IssueDate>2026-08-01</cbc:IssueDate>
  <cbc:DocumentCurrencyCode>CHF</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty><cac:Party>
    <cac:PartyName><cbc:Name>Papeterie SA</cbc:Name></cac:PartyName>
  </cac:Party></cac:AccountingSupplierParty>
  <cac:LegalMonetaryTotal>
    <cbc:TaxExclusiveAmount currencyID="CHF">12.5</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount currencyID="CHF">13.50</cbc:TaxInclusiveAmount>
  </cac:LegalMonetaryTotal>
</CreditNote>''';
    final p = parseInboundEInvoice(xml);
    expect(p.isCreditNote, isTrue);
    expect(p.supplierName, 'Papeterie SA');
    expect(p.dueDate, isNull);
    expect(p.netCents, 1250);
    expect(p.grossCents, 1350);
    // No TaxTotal: the tax is what separates the two totals.
    expect(p.taxCents, 100);
  });

  test('every refusal carries its reason', () {
    InboundEInvoiceProblem problem(String xml) {
      try {
        parseInboundEInvoice(xml);
      } on InboundEInvoiceException catch (e) {
        return e.problem;
      }
      fail('accepted');
    }

    expect(problem('not xml <<'), InboundEInvoiceProblem.notXml);
    expect(problem('<html/>'), InboundEInvoiceProblem.unsupportedRoot);
    expect(problem('<Invoice/>'), InboundEInvoiceProblem.missingField);
    const badAmount = '''<Invoice><ID>1</ID><IssueDate>2026-01-01</IssueDate>
<DocumentCurrencyCode>EUR</DocumentCurrencyCode>
<AccountingSupplierParty><Party><PartyName><Name>S</Name></PartyName></Party></AccountingSupplierParty>
<LegalMonetaryTotal><TaxExclusiveAmount>1.005</TaxExclusiveAmount>
<TaxInclusiveAmount>1.005</TaxInclusiveAmount></LegalMonetaryTotal></Invoice>''';
    expect(problem(badAmount), InboundEInvoiceProblem.missingField);
    expect(
      problem(
        badAmount
            .replaceAll('1.005', '1.00')
            .replaceAll('2026-01-01', '2026-02-30'),
      ),
      InboundEInvoiceProblem.missingField,
    );
  });
}
