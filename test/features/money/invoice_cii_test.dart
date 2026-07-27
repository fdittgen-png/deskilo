// SPDX-License-Identifier: 0BSD
//
// EN 16931 as CII (0073) — the syntax Factur-X embeds in the PDF. Same
// semantics as the UBL builder, different grammar, and every group is an
// XSD *sequence*: an element out of order is rejected before a single
// business rule is read.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

Invoice _invoice({String replacesNumber = ''}) => Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 7, 26),
      period: '2026-07',
      title: '2026-07',
      lines: const [
        InvoiceLine(kind: 'subscription', label: '50', amountCents: 15000),
        InvoiceLine(
            kind: 'overage', label: '', quantity: 2, amountCents: 1600),
        InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
      ],
      totalCents: 6600,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      replacesNumber: replacesNumber,
    );

const _sellerO = InvoiceParty(
  name: 'Test Space',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812345678',
  taxExemptionReason: 'Services outside the scope of VAT',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

XmlDocument _doc({
  Invoice? invoice,
  InvoiceParty seller = _sellerO,
  InvoiceParty buyer = _buyer,
  String iban = '',
}) =>
    XmlDocument.parse(buildInvoiceCii(
      invoice: invoice ?? _invoice(),
      seller: seller,
      buyer: buyer,
      iban: iban,
      lineText: (line) => invoiceLineText(null, line),
    ));

/// A direct child of `rsm:ExchangedDocument` — the invoice head. Scoped on
/// purpose: `ram:ID` also names the guideline and both parties.
String _head(XmlDocument doc, String name) => doc
    .findAllElements('rsm:ExchangedDocument')
    .single
    .findElements('ram:$name')
    .single
    .innerText;

/// The child element names of the first [parent], in document order.
List<String> _order(XmlDocument doc, String parent) => doc
    .findAllElements('ram:$parent')
    .first
    .childElements
    .map((e) => e.name.local)
    .toList();

void main() {
  test('the document declares the EN 16931 guideline and the invoice head',
      () {
    final doc = _doc();

    expect(
      doc
          .findAllElements('ram:GuidelineSpecifiedDocumentContextParameter')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      'urn:cen.eu:en16931:2017',
      reason: 'Factur-X EN 16931 profile, not a downgraded BASIC',
    );
    expect(_head(doc, 'ID'), 'INV-2026-0001');
    expect(_head(doc, 'TypeCode'), '380');
    expect(
      doc.findAllElements('udt:DateTimeString').first.innerText,
      '20260726',
      reason: 'CII dates are format 102 — YYYYMMDD',
    );
    expect(
      doc.findAllElements('udt:DateTimeString').first.getAttribute('format'),
      '102',
    );
  });

  test('the solde maps to prepaid + due, and payments never become lines',
      () {
    final doc = _doc();

    expect(doc.findAllElements('ram:IncludedSupplyChainTradeLineItem'),
        hasLength(2));
    final totals = doc
        .findAllElements('ram:SpecifiedTradeSettlementHeaderMonetarySummation')
        .single;
    String total(String name) =>
        totals.findElements('ram:$name').single.innerText;
    expect(total('LineTotalAmount'), '166.00');
    expect(total('TaxBasisTotalAmount'), '166.00');
    expect(total('GrandTotalAmount'), '166.00');
    expect(total('TotalPrepaidAmount'), '100.00');
    expect(total('DuePayableAmount'), '66.00');
  });

  test('POSTCODE comes first in a CII address — the sequence is not the '
      'human order', () {
    final order = _order(_doc(), 'PostalTradeAddress');

    expect(order, ['PostcodeCode', 'LineOne', 'CityName', 'CountryID']);
  });

  test('a category-O seller is identified by its legal organisation and '
      'carries NO tax registration (BR-O-02/BR-CO-26)', () {
    final doc = _doc();
    final seller = doc.findAllElements('ram:SellerTradeParty').single;

    expect(
      seller
          .findAllElements('ram:SpecifiedLegalOrganization')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      '812345678',
    );
    expect(seller.findAllElements('ram:SpecifiedTaxRegistration'), isEmpty);

    final tax = doc.findAllElements('ram:ApplicableTradeTax').last;
    expect(tax.findElements('ram:CategoryCode').single.innerText, 'O');
    expect(tax.findElements('ram:ExemptionReasonCode').single.innerText,
        'VATEX-EU-O');
    expect(tax.findElements('ram:RateApplicablePercent'), isEmpty,
        reason: 'BR-O-05: category O carries no rate');
    // The header tax group follows the norm's own element order.
    expect(_order(_doc(), 'ApplicableTradeTax'), [
      'TypeCode',
      'CategoryCode',
    ], reason: 'the LINE-level group is the first one in the document');
  });

  test('an exempt seller carries its VAT id, the zero rate and the reason',
      () {
    final doc = _doc(
      seller: _sellerO.copyWith(
        vatRegime: 'exempt',
        vatId: 'FR12812345678',
        taxExemptionReason: 'Franchise en base de TVA',
      ),
    );

    expect(
      doc
          .findAllElements('ram:SellerTradeParty')
          .single
          .findAllElements('ram:SpecifiedTaxRegistration')
          .single
          .findElements('ram:ID')
          .single
          .innerText,
      'FR12812345678',
    );
    final tax = doc.findAllElements('ram:ApplicableTradeTax').last;
    expect(tax.findElements('ram:CategoryCode').single.innerText, 'E');
    expect(tax.findElements('ram:RateApplicablePercent').single.innerText,
        '0');
    expect(tax.findElements('ram:ExemptionReasonCode').single.innerText,
        'VATEX-FR-FRANCHISE');
    expect(tax.findElements('ram:ExemptionReason').single.innerText,
        contains('Franchise'));
  });

  test('the invoiced month rides as a billing period', () {
    final period = _doc().findAllElements('ram:BillingSpecifiedPeriod').single;

    expect(
      period.findAllElements('udt:DateTimeString').map((e) => e.innerText),
      ['20260701', '20260731'],
    );
  });

  test('an IBAN becomes credit-transfer payment means', () {
    final means = _doc(iban: 'FR76 3000 4000 0312 3456 7890 143')
        .findAllElements('ram:SpecifiedTradeSettlementPaymentMeans')
        .single;

    expect(means.findElements('ram:TypeCode').single.innerText, '30');
    expect(
      means
          .findAllElements('ram:PayeePartyCreditorFinancialAccount')
          .single
          .findElements('ram:IBANID')
          .single
          .innerText,
      'FR7630004000031234567890143',
    );
  });

  test('a replacement is corrective (384) and names the document it '
      'replaces', () {
    final doc = _doc(invoice: _invoice(replacesNumber: 'INV-2026-0000'));

    expect(_head(doc, 'TypeCode'), '384');
    expect(
      doc
          .findAllElements('ram:InvoiceReferencedDocument')
          .single
          .findElements('ram:IssuerAssignedID')
          .single
          .innerText,
      'INV-2026-0000',
    );
  });

  test('the settlement group keeps the norm\'s element order', () {
    final order = _order(_doc(iban: 'FR7630004000031234567890143'),
        'ApplicableHeaderTradeSettlement');

    expect(order, [
      'InvoiceCurrencyCode',
      'SpecifiedTradeSettlementPaymentMeans',
      'ApplicableTradeTax',
      'BillingSpecifiedPeriod',
      'SpecifiedTradeSettlementHeaderMonetarySummation',
    ]);
  });
}
