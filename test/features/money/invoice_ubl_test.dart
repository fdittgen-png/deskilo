// SPDX-License-Identifier: 0BSD
//
// EN 16931 e-invoice (0066/0069): the UBL 2.1 document maps the app's
// SOLDE model onto the norm — charges are InvoiceLines, confirmed
// payments are PrepaidAmount (BT-113), the payable amount is the solde
// (BT-115) — and it obeys the norm's FATAL rules, which differ per tax
// category: BR-CO-26 (a seller identifier exists at all), BR-O-02/05 (no
// tax id and no rate outside the scope of VAT), BR-E-02/05/10 (VAT id,
// zero rate and an exemption reason when exempt).
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

Invoice _invoice({String replacesNumber = '', List<InvoiceLine>? lines}) =>
    Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 7, 26),
      period: '2026-07',
      title: '2026-07',
      lines: lines ??
          const [
            InvoiceLine(kind: 'subscription', label: '50', amountCents: 15000),
            InvoiceLine(
                kind: 'overage', label: '', quantity: 2, amountCents: 1600),
            InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
          ],
      totalCents: 6600,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test\n34120 Pézenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      replacesNumber: replacesNumber,
    );

/// A seller outside the scope of VAT — the app's default regime.
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

String _xml({
  Invoice? invoice,
  InvoiceParty seller = _sellerO,
  InvoiceParty buyer = _buyer,
  String iban = '',
}) =>
    buildInvoiceUbl(
      invoice: invoice ?? _invoice(),
      seller: seller,
      buyer: buyer,
      iban: iban,
      lineText: (line) => invoiceLineText(null, line),
    );

extension on XmlDocument {
  String one(String name) => findAllElements('cbc:$name').first.innerText;
  Iterable<String> all(String name) =>
      findAllElements('cbc:$name').map((e) => e.innerText);
}

void main() {
  test('the EU set has all 27 member states and nothing else', () {
    expect(euCountryCodes, hasLength(27));
    expect(isEuCountry('fr'), isTrue);
    expect(isEuCountry('DE'), isTrue);
    expect(isEuCountry('CH'), isFalse);
    expect(isEuCountry('GB'), isFalse);
  });

  test(
      'the document carries the EN 16931 customization, the invoiced '
      'PERIOD, both parties and the solde mapping', () {
    final doc = XmlDocument.parse(_xml());

    expect(doc.one('CustomizationID'), 'urn:cen.eu:en16931:2017');
    expect(doc.one('ID'), 'INV-2026-0001');
    expect(doc.one('IssueDate'), '2026-07-26');
    expect(doc.one('InvoiceTypeCode'), '380');
    expect(doc.one('DocumentCurrencyCode'), 'EUR');
    // BT-73/74 — the month as a period, not prose in a note.
    final period = doc.findAllElements('cac:InvoicePeriod').single;
    expect(period.findElements('cbc:StartDate').single.innerText,
        '2026-07-01');
    expect(period.findElements('cbc:EndDate').single.innerText, '2026-07-31');
    expect(doc.findAllElements('cbc:Note'), isEmpty);

    expect(doc.all('RegistrationName'), ['Test Space', 'Ana Martin']);
    expect(doc.all('CityName'), ['Pézenas', 'Pézenas']);
    expect(doc.all('PostalZone'), ['34120', '34120']);
    expect(doc.all('IdentificationCode').toSet(), {'FR'});

    // Solde mapping: charges 166.00 as lines, the 100.00 payment as
    // PrepaidAmount, payable = 66.00.
    expect(doc.findAllElements('cac:InvoiceLine'), hasLength(2),
        reason: 'payments are PrepaidAmount, never negative lines');
    expect(doc.one('LineExtensionAmount'), '166.00');
    expect(doc.one('PrepaidAmount'), '100.00');
    expect(doc.one('PayableAmount'), '66.00');
  });

  test(
      'BR-CO-26 + BR-O-02/05: outside the scope of VAT the seller is '
      'identified by its REGISTRATION number, carries no tax scheme and '
      'no rate', () {
    final doc = XmlDocument.parse(_xml());

    final seller = doc.findAllElements('cac:AccountingSupplierParty').single;
    expect(
      seller.findAllElements('cbc:CompanyID').map((e) => e.innerText),
      ['812345678'],
      reason: 'BR-CO-26 is satisfied by BT-30, the only identifier '
          'category O allows',
    );
    expect(seller.findAllElements('cac:PartyTaxScheme'), isEmpty,
        reason: 'BR-O-02 forbids a seller tax identifier');
    final category = doc.findAllElements('cac:TaxCategory').single;
    expect(category.findElements('cbc:ID').single.innerText, 'O');
    expect(category.findElements('cbc:Percent'), isEmpty,
        reason: 'BR-O-05: category O carries no rate');
    expect(category.findElements('cbc:TaxExemptionReasonCode').single.innerText,
        'VATEX-EU-O', reason: 'BR-O-10 wants the coded reason');
    expect(doc.one('TaxAmount'), '0.00');
  });

  test(
      'BR-E-02/05/10: an exempt seller carries its VAT id, the zero rate '
      "and France's franchise code", () {
    final doc = XmlDocument.parse(_xml(
      seller: _sellerO.copyWith(
        vatRegime: 'exempt',
        vatId: 'FR12812345678',
        taxExemptionReason: 'Franchise en base de TVA, art. 293 B du CGI',
      ),
    ));

    final seller = doc.findAllElements('cac:AccountingSupplierParty').single;
    expect(
      seller
          .findAllElements('cac:PartyTaxScheme')
          .single
          .findElements('cbc:CompanyID')
          .single
          .innerText,
      'FR12812345678',
    );
    final category = doc.findAllElements('cac:TaxCategory').single;
    expect(category.findElements('cbc:ID').single.innerText, 'E');
    expect(category.findElements('cbc:Percent').single.innerText, '0');
    expect(
      category.findElements('cbc:TaxExemptionReasonCode').single.innerText,
      'VATEX-FR-FRANCHISE',
    );
    expect(category.findElements('cbc:TaxExemptionReason').single.innerText,
        contains('293 B'));
    // Every line repeats the category (BR-E-05 applies per line too).
    for (final line in doc.findAllElements('cac:ClassifiedTaxCategory')) {
      expect(line.findElements('cbc:ID').single.innerText, 'E');
      expect(line.findElements('cbc:Percent').single.innerText, '0');
    }
  });

  test('the buyer VAT id rides along when the member invoices as a business',
      () {
    final doc = XmlDocument.parse(
      _xml(buyer: _buyer.copyWith(vatId: 'FR99887766554')),
    );
    expect(
      doc
          .findAllElements('cac:AccountingCustomerParty')
          .single
          .findAllElements('cac:PartyTaxScheme')
          .single
          .findElements('cbc:CompanyID')
          .single
          .innerText,
      'FR99887766554',
    );
  });

  test('an IBAN becomes PaymentMeans — where the payer must transfer', () {
    final doc = XmlDocument.parse(_xml(iban: 'FR76 3000 4000 0312 3456 7890 143'));
    final means = doc.findAllElements('cac:PaymentMeans').single;
    expect(means.findElements('cbc:PaymentMeansCode').single.innerText, '30');
    expect(
      means
          .findAllElements('cbc:ID')
          .single
          .innerText,
      'FR7630004000031234567890143',
      reason: 'spaces are display sugar, not part of the account number',
    );
    // No IBAN configured → no group at all (an empty one is invalid).
    expect(
      XmlDocument.parse(_xml()).findAllElements('cac:PaymentMeans'),
      isEmpty,
    );
  });

  test('a quantified position keeps quantity × unit price consistent', () {
    final doc = XmlDocument.parse(_xml());
    final overage = doc.findAllElements('cac:InvoiceLine').last;
    expect(
      overage.findElements('cbc:InvoicedQuantity').single.innerText,
      '2',
    );
    expect(
      overage
          .findAllElements('cac:Price')
          .single
          .findElements('cbc:PriceAmount')
          .single
          .innerText,
      '8.00',
      reason: '2 × 8.00 = the 16.00 line amount',
    );
  });

  test('a replacement is a CORRECTIVE invoice (384) referencing the '
      'replaced number', () {
    final doc = XmlDocument.parse(
      _xml(invoice: _invoice(replacesNumber: 'INV-2026-0000')),
    );
    expect(doc.one('InvoiceTypeCode'), '384');
    expect(
      doc
          .findAllElements('cac:InvoiceDocumentReference')
          .single
          .findElements('cbc:ID')
          .single
          .innerText,
      'INV-2026-0000',
    );
  });

  group('readiness', () {
    EInvoiceReadiness check({
      InvoiceParty seller = _sellerO,
      InvoiceParty buyer = _buyer,
      Invoice? invoice,
    }) =>
        checkEInvoiceReadiness(
          invoice: invoice ?? _invoice(),
          seller: seller,
          buyer: buyer,
        );

    test('a complete category-O identity is ready and clean', () {
      expect(check().ready, isTrue);
      expect(check().clean, isTrue);
    });

    test('no seller identifier at all blocks the export (BR-CO-26)', () {
      final readiness = check(seller: _sellerO.copyWith(legalId: ''));
      expect(readiness.ready, isFalse);
      expect(readiness.blocking, contains(EInvoiceGap.missingLegalId));
    });

    test('exempt without a VAT id blocks the export (BR-E-02)', () {
      final readiness = check(
        seller: _sellerO.copyWith(vatRegime: 'exempt', legalId: ''),
      );
      expect(readiness.blocking, contains(EInvoiceGap.missingVatId));
    });

    test('a VAT-charging workspace cannot export at all', () {
      final readiness = check(
        seller: _sellerO.copyWith(vatRegime: 'vat_registered'),
      );
      expect(readiness.blocking, contains(EInvoiceGap.vatNotSupported));
      expect(
        EInvoiceGap.vatNotSupported.fixableInSettings,
        isTrue,
        reason: 'the regime is a setting — the owner can correct a mistake',
      );
    });

    test('a missing country on either side blocks it (BR-09/BR-11)', () {
      expect(check(seller: _sellerO.copyWith(country: '')).blocking,
          contains(EInvoiceGap.missingSellerCountry));
      expect(check(buyer: _buyer.copyWith(country: '')).blocking,
          contains(EInvoiceGap.missingBuyerCountry));
    });

    test('an all-credit month has no invoice to send (BR-16)', () {
      final readiness = check(
        invoice: _invoice(lines: const [
          InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
        ]),
      );
      expect(readiness.blocking, contains(EInvoiceGap.noChargeLines));
    });

    test('a missing city or post code only WARNS — the norm survives it',
        () {
      final readiness =
          check(seller: _sellerO.copyWith(city: '', postalCode: ''));
      expect(readiness.ready, isTrue);
      expect(readiness.clean, isFalse);
      expect(readiness.warnings, [
        EInvoiceGap.missingSellerCity,
        EInvoiceGap.missingSellerPostalCode,
      ]);
    });
  });
}
