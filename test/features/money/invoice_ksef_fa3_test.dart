// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — FA(3), the Polish invoice KSeF numbers. The schema is checked
// in CI (einvoice_samples_test + the official XSD); these pin what the
// schema leaves to the issuer — which band a rate fills, how a buyer is
// identified, the annotations, a correction.
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_ksef_fa3.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

Invoice _invoice({
  int gross = 24600,
  double percent = 23,
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
    number: 'FV/2026/09/42',
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
    currency: 'PLN',
    memberName: 'Pracownia',
    memberAddress: '',
    workspaceName: 'Przestrzen',
    workspaceAddress: '',
    issuerName: 'Flo',
    signature: 'f' * 64,
    replacesNumber: replacesNumber,
  );
}

const _seller = InvoiceParty(
  name: 'Przestrzen Testowa Sp. z o.o.',
  street: 'ul. Prosta 1',
  city: 'Warszawa',
  postalCode: '00-850',
  country: 'PL',
  vatId: 'PL 526-000-12-46',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Pracownia Polnoc Sp. z o.o.',
  street: 'ul. Dluga 5',
  city: 'Krakow',
  postalCode: '31-147',
  country: 'PL',
  vatId: 'PL6750001923',
);

XmlDocument _doc({
  Invoice? invoice,
  InvoiceParty buyer = _buyer,
  DateTime? correctedIssuedAt,
}) => XmlDocument.parse(
  buildInvoiceKsefFa3(
    invoice: invoice ?? _invoice(),
    seller: _seller,
    buyer: buyer,
    lineText: (line) => invoiceLineText(const ReportStrings(), line),
    correctedIssuedAt: correctedIssuedAt,
  ),
);

extension on XmlDocument {
  String one(String name) => findAllElements(name).first.innerText;
  Iterable<String> all(String name) =>
      findAllElements(name).map((e) => e.innerText);
}

void main() {
  test('the header names FA (3), variant 3', () {
    final doc = _doc();
    final code = doc.findAllElements('KodFormularza').single;
    expect(code.getAttribute('kodSystemowy'), 'FA (3)');
    expect(code.getAttribute('wersjaSchemy'), '1-0E');
    expect(code.innerText, 'FA');
    expect(doc.one('WariantFormularza'), '3');
    expect(doc.one('DataWytworzeniaFa'), endsWith('Z'));
  });

  test('a NIP is digits only, whatever the VAT id looked like', () {
    expect(_doc().all('NIP').toList(), ['5260001246', '6750001923']);
  });

  test('23 % fills the basic-rate band', () {
    final doc = _doc();
    expect(doc.one('P_13_1'), '200.00');
    expect(doc.one('P_14_1'), '46.00');
    expect(doc.one('P_15'), '246.00');
    expect(doc.one('P_12'), '23');
    expect(doc.one('RodzajFaktury'), 'VAT');
  });

  test('8 % fills the first reduced band', () {
    final doc = _doc(invoice: _invoice(percent: 8, gross: 10800));
    expect(doc.one('P_13_2'), '100.00');
    expect(doc.one('P_14_2'), '8.00');
    expect(doc.all('P_13_1'), isEmpty);
    expect(doc.one('P_12'), '8');
  });

  test('an exempt supply goes to P_13_7, flagged with its legal basis', () {
    final doc = _doc(
      invoice: _invoice(percent: 0, category: 'E', gross: 10000),
    );
    expect(doc.one('P_13_7'), '100.00');
    expect(doc.one('P_12'), 'zw');
    expect(doc.one('P_19'), '1');
    expect(doc.all('P_19A'), isNotEmpty);
    expect(doc.all('P_19N'), isEmpty);
  });

  test('a taxed invoice declares no exemption (P_19N)', () {
    expect(_doc().one('P_19N'), '1');
  });

  test('a reverse charge for a foreign buyer is P_13_9 / np II', () {
    final doc = _doc(
      invoice: _invoice(percent: 0, category: 'AE', gross: 10000),
      buyer: _buyer.copyWith(country: 'DE', vatId: 'DE123456789'),
    );
    expect(doc.one('P_13_9'), '100.00');
    expect(doc.one('P_12'), 'np II');
    expect(doc.one('P_18'), '2');
    expect(doc.one('KodUE'), 'DE');
    expect(doc.one('NrVatUE'), '123456789');
  });

  test('a domestic reverse charge is P_13_10 / oo, and P_18 says so', () {
    final doc = _doc(
      invoice: _invoice(percent: 0, category: 'AE', gross: 10000),
    );
    expect(doc.one('P_13_10'), '100.00');
    expect(doc.one('P_12'), 'oo');
    expect(doc.one('P_18'), '1');
  });

  test('a Greek VAT number is coded EL, as the EU lists it', () {
    final doc = _doc(
      buyer: _buyer.copyWith(country: 'GR', vatId: 'GR123456789'),
    );
    expect(doc.one('KodUE'), 'EL');
  });

  test('a private person without an id is BrakID', () {
    final doc = _doc(buyer: _buyer.copyWith(vatId: ''));
    expect(doc.one('BrakID'), '1');
    expect(
      doc.findAllElements('NIP'),
      hasLength(1),
      reason: 'only the seller has one',
    );
  });

  test('every FA(3) annotation is stated, and JST / GV are present', () {
    final doc = _doc();
    for (final flag in ['P_16', 'P_17', 'P_18A', 'P_23']) {
      expect(doc.one(flag), '2', reason: flag);
    }
    expect(doc.one('P_22N'), '1');
    expect(doc.one('P_PMarzyN'), '1');
    expect(doc.one('JST'), '2');
    expect(doc.one('GV'), '2');
  });

  test(
    'a correction is KOR, keeps its negative amounts, names what it corrects',
    () {
      final doc = _doc(
        invoice: _invoice(gross: -24600, replacesNumber: 'FV/2026/09/41'),
        correctedIssuedAt: DateTime(2026, 9, 15),
      );
      expect(doc.one('RodzajFaktury'), 'KOR');
      expect(doc.one('P_13_1'), '-200.00');
      expect(doc.one('P_15'), '-246.00');
      expect(doc.one('NrFaKorygowanej'), 'FV/2026/09/41');
      expect(doc.one('DataWystFaKorygowanej'), '2026-09-15');
      expect(doc.one('NrKSeFN'), '1');
      expect(doc.all('Platnosc'), isEmpty);
    },
  );
}
