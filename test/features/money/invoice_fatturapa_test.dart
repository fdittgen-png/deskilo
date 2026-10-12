// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — FatturaPA: the Italian invoice SdI accepts. The schema itself
// is checked in CI (einvoice_samples_test + the official XSD); these
// pin the Italian rules the schema cannot see — why a 0 % line carries
// no VAT (Natura), the stamp duty, the routing code, a credit note.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_fatturapa.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

Invoice _invoice({
  int gross = 24400,
  double percent = 22,
  String category = 'S',
  String replacesNumber = '',
}) {
  final net = percent > 0
      ? vatSplit(gross.abs(), percent).netCents
      : gross.abs();
  final signedNet = gross < 0 ? -net : net;
  return Invoice(
    id: 'inv-1',
    workspaceId: 'ws-1',
    memberId: 'member-1',
    number: 'IT-2026/0042',
    issuedAt: DateTime(2026, 9, 30),
    period: '2026-09',
    title: '2026-09',
    lines: [
      InvoiceLine(
        kind: 'subscription',
        label: '50',
        amountCents: gross,
        vatPercent: percent,
        vatCategory: category,
      ),
    ],
    vatTotals: [
      InvoiceVatTotal(
        percent: percent,
        category: category,
        grossCents: gross,
        netCents: signedNet,
        vatCents: gross - signedNet,
      ),
    ],
    totalCents: gross,
    currency: 'EUR',
    memberName: 'Studio Nord',
    memberAddress: '',
    workspaceName: 'Spazio Prova',
    workspaceAddress: '',
    issuerName: 'Flo',
    signature: 'f' * 64,
    replacesNumber: replacesNumber,
  );
}

const _seller = InvoiceParty(
  name: 'Spazio Prova S.r.l.',
  street: 'Via Roma 1',
  city: 'Milano',
  postalCode: '20121',
  country: 'IT',
  subdivision: 'MI',
  vatId: 'IT01234567897',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Studio Nord S.r.l.',
  street: 'Corso Italia 10',
  city: 'Torino',
  postalCode: '10121',
  country: 'IT',
  vatId: 'IT09876543217',
  endpointId: 'KRRH6B9',
);

XmlDocument _doc({
  Invoice? invoice,
  InvoiceParty seller = _seller,
  InvoiceParty buyer = _buyer,
}) => XmlDocument.parse(
  buildInvoiceFatturaPa(
    invoice: invoice ?? _invoice(),
    seller: seller,
    buyer: buyer,
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
  ),
);

extension on XmlDocument {
  String one(String name) => findAllElements(name).first.innerText;
  Iterable<String> all(String name) =>
      findAllElements(name).map((e) => e.innerText);
}

void main() {
  test('a private buyer gets FPR12, routed by its recipient code', () {
    final doc = _doc();
    expect(doc.rootElement.getAttribute('versione'), 'FPR12');
    expect(doc.one('FormatoTrasmissione'), 'FPR12');
    expect(doc.one('CodiceDestinatario'), 'KRRH6B9');
    expect(doc.all('PECDestinatario'), isEmpty);
    expect(doc.one('RegimeFiscale'), 'RF01');
    expect(doc.one('TipoDocumento'), 'TD01');
  });

  test('a taxed line states the net, the rate and the collectable tax', () {
    final doc = _doc();
    expect(doc.one('PrezzoTotale'), '200.00');
    expect(doc.one('AliquotaIVA'), '22.00');
    expect(doc.one('ImponibileImporto'), '200.00');
    expect(doc.one('Imposta'), '44.00');
    expect(doc.one('EsigibilitaIVA'), 'I');
    expect(doc.all('Natura'), isEmpty);
    expect(doc.one('ImportoTotaleDocumento'), '244.00');
  });

  test('a PEC mailbox routes as 0000000 plus the address', () {
    final doc = _doc(
      buyer: _buyer.copyWith(endpointId: 'acquisti@pec.example'),
    );
    expect(doc.one('CodiceDestinatario'), '0000000');
    expect(doc.one('PECDestinatario'), 'acquisti@pec.example');
  });

  test('a foreign buyer is routed as XXXXXXX', () {
    final doc = _doc(
      buyer: _buyer.copyWith(
        country: 'GB',
        postalCode: 'SW1A 1AA',
        vatId: 'GB980780684',
        endpointId: '',
      ),
    );
    expect(doc.one('CodiceDestinatario'), 'XXXXXXX');
    expect(
      doc.findAllElements('CAP').last.innerText,
      '00000',
      reason: 'a foreign postcode does not fit the five-digit CAP',
    );
  });

  test('a public buyer (six-character office code) gets FPA12', () {
    final doc = _doc(buyer: _buyer.copyWith(endpointId: 'UFY9MH'));
    expect(doc.rootElement.getAttribute('versione'), 'FPA12');
    expect(doc.one('CodiceDestinatario'), 'UFY9MH');
  });

  group('Natura — why a line carries no VAT', () {
    String natura(String category, {String buyerCountry = 'IT'}) => _doc(
      invoice: _invoice(percent: 0, category: category),
      buyer: _buyer.copyWith(country: buyerCountry),
    ).one('Natura');

    test('outside the scope → N2.2', () => expect(natura('O'), 'N2.2'));
    test('exempt → N4', () => expect(natura('E'), 'N4'));
    test('zero-rated → N3.5', () => expect(natura('Z'), 'N3.5'));
    test('intra-EU supply → N3.2', () => expect(natura('K'), 'N3.2'));
    test('export → N3.1', () => expect(natura('G'), 'N3.1'));
    test(
      'a reverse charge abroad → N2.1',
      () => expect(natura('AE', buyerCountry: 'DE'), 'N2.1'),
    );
    test(
      'a domestic reverse charge → N6.9',
      () => expect(natura('AE'), 'N6.9'),
    );
  });

  group('stamp duty', () {
    test('€2 on an exempt document above €77.47', () {
      final doc = _doc(
        invoice: _invoice(percent: 0, category: 'E', gross: 7748),
      );
      expect(doc.one('BolloVirtuale'), 'SI');
      expect(doc.one('ImportoBollo'), '2.00');
    });

    test('none at €77.47 or below', () {
      final doc = _doc(
        invoice: _invoice(percent: 0, category: 'E', gross: 7747),
      );
      expect(doc.all('DatiBollo'), isEmpty);
    });

    test('none on a taxed document', () {
      expect(_doc().all('DatiBollo'), isEmpty);
    });

    test('none on an intra-EU supply, whatever its amount', () {
      final doc = _doc(
        invoice: _invoice(percent: 0, category: 'K', gross: 50000),
      );
      expect(doc.all('DatiBollo'), isEmpty);
    });
  });

  test('a seller charging no VAT is on the flat-rate regime (RF19)', () {
    final doc = _doc(
      invoice: _invoice(percent: 0, category: 'O'),
      seller: _seller.copyWith(vatRegime: 'not_subject'),
    );
    expect(doc.one('RegimeFiscale'), 'RF19');
  });

  test('a credit note is TD04, its amounts stated as what is credited', () {
    final doc = _doc(
      invoice: _invoice(gross: -24400, replacesNumber: 'IT-2026/0041'),
    );
    expect(doc.one('TipoDocumento'), 'TD04');
    expect(doc.one('ImportoTotaleDocumento'), '244.00');
    expect(doc.one('PrezzoTotale'), '200.00');
    expect(doc.one('Imposta'), '44.00');
    expect(doc.one('IdDocumento'), 'IT-2026/0041');
    expect(
      doc.all('DatiPagamento'),
      isEmpty,
      reason: 'nothing is owed on a credit note',
    );
  });

  test('ProgressivoInvio stays within ten basic-latin characters', () {
    final long = _invoice().copyWith(number: 'INVOICE-2026-000000042');
    final value = _doc(invoice: long).one('ProgressivoInvio');
    expect(value, matches(RegExp(r'^[A-Z0-9]{1,10}$')));
    expect(
      _doc(invoice: long).one('ProgressivoInvio'),
      value,
      reason: 'the same invoice always gets the same id',
    );
  });
}
