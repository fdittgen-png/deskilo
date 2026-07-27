// SPDX-License-Identifier: 0BSD
//
// EN 16931 e-invoice (0066): the UBL 2.1 document maps the app's SOLDE
// model onto the norm — charges are InvoiceLines, confirmed payments
// are PrepaidAmount (BT-113), the payable amount is the solde
// (BT-115), and the VAT-free reality carries tax category O with the
// mandated exemption reason.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
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
        InvoiceLine(kind: 'service', label: 'Coffee ×3', amountCents: 450),
        InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
      ],
      totalCents: 5450,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue Test\n34120 Pézenas',
      workspaceName: 'Test Space',
      workspaceAddress: '2 Place du Marché, 34120 Pézenas',
      issuerName: 'Flo',
      signature: 'f' * 64,
      replacesNumber: replacesNumber,
    );

void main() {
  test('the EU set has all 27 member states and nothing else', () {
    expect(euCountryCodes, hasLength(27));
    expect(isEuCountry('fr'), isTrue);
    expect(isEuCountry('DE'), isTrue);
    expect(isEuCountry('CH'), isFalse);
    expect(isEuCountry('GB'), isFalse);
  });

  test('the UBL document carries the EN 16931 customization, both '
      'parties, the solde mapping and category-O tax', () {
    final xml = buildInvoiceUbl(
      invoice: _invoice(),
      countryCode: 'FR',
      lineText: (line) => invoiceLineText(null, line),
    );
    final doc = XmlDocument.parse(xml);
    String one(String name) =>
        doc.findAllElements('cbc:$name').first.innerText;

    expect(one('CustomizationID'), 'urn:cen.eu:en16931:2017');
    expect(one('ID'), 'INV-2026-0001');
    expect(one('IssueDate'), '2026-07-26');
    expect(one('InvoiceTypeCode'), '380');
    expect(one('DocumentCurrencyCode'), 'EUR');
    expect(
      doc.findAllElements('cbc:RegistrationName').map((e) => e.innerText),
      ['Test Space', 'Ana Martin'],
    );
    expect(
      doc
          .findAllElements('cbc:IdentificationCode')
          .map((e) => e.innerText)
          .toSet(),
      {'FR'},
    );

    // Solde mapping: charges 154.50 as lines, the 100.00 payment as
    // PrepaidAmount, payable = 54.50.
    expect(doc.findAllElements('cac:InvoiceLine'), hasLength(2),
        reason: 'payments are PrepaidAmount, never negative lines');
    expect(one('LineExtensionAmount'), '154.50');
    expect(one('PrepaidAmount'), '100.00');
    expect(one('PayableAmount'), '54.50');

    // VAT-free: zero tax, category O with the exemption reason.
    expect(one('TaxAmount'), '0.00');
    expect(
      doc
          .findAllElements('cac:TaxCategory')
          .first
          .findElements('cbc:ID')
          .first
          .innerText,
      'O',
    );
    expect(one('TaxExemptionReason'), isNotEmpty);
  });

  test('a replacement is a CORRECTIVE invoice (384) referencing the '
      'replaced number', () {
    final xml = buildInvoiceUbl(
      invoice: _invoice(replacesNumber: 'INV-2026-0000'),
      countryCode: 'DE',
      lineText: (line) => invoiceLineText(null, line),
    );
    final doc = XmlDocument.parse(xml);
    expect(doc.findAllElements('cbc:InvoiceTypeCode').first.innerText,
        '384');
    expect(
      doc
          .findAllElements('cac:InvoiceDocumentReference')
          .first
          .findElements('cbc:ID')
          .first
          .innerText,
      'INV-2026-0000',
    );
  });
}
