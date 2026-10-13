// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the UBL profiles: the same EN 16931 content under Peppol BIS,
// XRechnung or CIUS-RO, each adding only what it makes mandatory. The
// bare EN 16931 document stays exactly what it was; the official
// validators run on one sample of each in CI (einvoice_samples_test).
import 'package:deskilo/features/money/domain/einvoice_format.dart';
import 'package:deskilo/features/money/domain/einvoice_input.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

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
  subdivision: 'BE',
  vatId: 'DE123456789',
  vatRegime: 'vat_registered',
  endpointId: 'billing@test.example',
  endpointScheme: 'EM',
  email: 'billing@test.example',
  phone: '+49 30 000000',
);

const _buyer = InvoiceParty(
  name: 'Bezirksamt',
  city: 'Berlin',
  postalCode: '10178',
  country: 'DE',
  endpointId: '04011000-12345-34',
  endpointScheme: leitwegIdScheme,
  reference: '04011000-12345-34',
);

XmlDocument _doc(UblProfile profile) => XmlDocument.parse(
  buildInvoiceUbl(EInvoiceInput(invoice: _invoice,
    seller: _seller,
    buyer: _buyer,
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    iban: 'DE02120300000000202051',
    dueDate: DateTime(2026, 10, 30),
    paymentTerms: '30 days net'),
    profile: profile),
);

Iterable<String> _texts(XmlDocument doc, String name) =>
    doc.findAllElements(name).map((e) => e.innerText);

void main() {
  test('the bare EN 16931 document carries none of the profile elements', () {
    final doc = _doc(UblProfile.en16931);
    expect(_texts(doc, 'cbc:CustomizationID'), ['urn:cen.eu:en16931:2017']);
    for (final name in [
      'cbc:ProfileID',
      'cbc:EndpointID',
      'cbc:DueDate',
      'cbc:CountrySubentity',
      'cac:Contact',
      'cac:PaymentTerms',
    ]) {
      expect(doc.findAllElements(name), isEmpty, reason: name);
    }
  });

  test('XRechnung claims its CIUS and carries what it makes mandatory', () {
    final doc = _doc(UblProfile.xrechnung);
    expect(_texts(doc, 'cbc:CustomizationID'), [
      UblProfile.xrechnung.customizationId,
    ]);
    expect(_texts(doc, 'cbc:ProfileID'), [UblProfile.xrechnung.profileId]);
    expect(_texts(doc, 'cbc:BuyerReference'), ['04011000-12345-34']);
    expect(_texts(doc, 'cbc:DueDate'), ['2026-10-30']);
    expect(_texts(doc, 'cbc:ElectronicMail'), ['billing@test.example']);
    expect(_texts(doc, 'cbc:Telephone'), ['+49 30 000000']);
    final endpoints = doc.findAllElements('cbc:EndpointID').toList();
    expect(endpoints.map((e) => e.getAttribute('schemeID')), [
      'EM',
      leitwegIdScheme,
    ]);
    for (final endpoint in endpoints) {
      expect(
        endpoint.parentElement!.childElements.first,
        endpoint,
        reason: 'BT-34/BT-49 come first in the party (UBL sequence)',
      );
    }
  });

  test('Peppol BIS and CIUS-RO claim their own identifiers', () {
    expect(_texts(_doc(UblProfile.peppolBis), 'cbc:CustomizationID'), [
      UblProfile.peppolBis.customizationId,
    ]);
    final ro = _doc(UblProfile.ciusRo);
    expect(_texts(ro, 'cbc:CustomizationID'), [
      UblProfile.ciusRo.customizationId,
    ]);
    expect(ro.findAllElements('cbc:ProfileID'), isEmpty);
    expect(_texts(ro, 'cbc:CountrySubentity'), ['BE']);
  });
}
