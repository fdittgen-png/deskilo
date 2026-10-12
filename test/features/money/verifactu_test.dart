// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the Verifactu record: the huella the AEAT recomputes, the chain
// an inspector walks, the QR the customer scans, and the record XML.
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/verifactu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'Espacio Test SL',
  country: 'ES',
  vatId: 'ESB12345674',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Taller Norte SL',
  country: 'ES',
  vatId: 'ESA87654321',
);

Invoice _invoice(String number, {int net = 10000, bool credit = false}) {
  final sign = credit ? -1 : 1;
  final vat = net * 21 ~/ 100;
  return Invoice(
    id: number,
    workspaceId: 'ws-1',
    memberId: 'member-1',
    number: number,
    issuedAt: DateTime(2027, 2, 3),
    title: '2027-02',
    lines: const [],
    vatTotals: [
      InvoiceVatTotal(
        percent: 21,
        category: 'S',
        grossCents: sign * (net + vat),
        netCents: sign * net,
        vatCents: sign * vat,
      ),
    ],
    totalCents: sign * (net + vat),
    currency: 'EUR',
    memberName: 'Taller Norte SL',
    memberAddress: '',
    workspaceName: 'Espacio Test SL',
    workspaceAddress: '',
    issuerName: 'Ana',
    signature: 'a' * 64,
  );
}

final _at = DateTime(2027, 2, 3, 10, 15, 30);

List<VerifactuRecord> _chain() {
  final records = <VerifactuRecord>[];
  for (final number in ['F-1', 'F-2', 'F-3']) {
    final previous = records.isEmpty ? null : records.last;
    records.add(
      verifactuRecordFor(
        invoice: _invoice(number),
        seller: _seller,
        buyer: _buyer,
        previousHuella: previous?.huella ?? '',
        previousNumber: previous?.number ?? '',
        previousIssueDate: previous?.issueDate ?? '',
        generatedAt: _at,
      ),
    );
  }
  return records;
}

void main() {
  test('the AEAT documentation example reproduces its published huella', () {
    expect(
      verifactuHuella(
        issuerNif: '89890001K',
        number: '12345678/G33',
        issueDate: '01-01-2024',
        type: 'F1',
        taxTotal: '12.35',
        grandTotal: '123.45',
        previousHuella: '',
        generatedAt: '2024-01-01T19:20:30+01:00',
      ),
      '3C464DAF61ACB827C65FDA19F352A4E3BDC2C640E9E9FC4CC058073F38F12F60',
    );
  });

  test('a record hashes exactly the AEAT concatenation of its own fields', () {
    final r = _chain().first;
    final literal =
        'IDEmisorFactura=B12345674&NumSerieFactura=F-1'
        '&FechaExpedicionFactura=03-02-2027&TipoFactura=F1'
        '&CuotaTotal=21.00&ImporteTotal=121.00&Huella='
        '&FechaHoraHusoGenRegistro=${verifactuTimestamp(_at)}';
    expect(
      r.huella,
      sha256.convert(utf8.encode(literal)).toString().toUpperCase(),
    );
    expect(r.huella, hasLength(64));
  });

  test('the cancellation huella hashes the anulación fields', () {
    const literal =
        'IDEmisorFacturaAnulada=B12345674'
        '&NumSerieFacturaAnulada=F-1&FechaExpedicionFacturaAnulada=03-02-2027'
        '&Huella=ABC&FechaHoraHusoGenRegistro=2027-02-03T10:15:30+01:00';
    expect(
      verifactuCancellationHuella(
        issuerNif: 'B12345674',
        number: 'F-1',
        issueDate: '03-02-2027',
        previousHuella: 'ABC',
        generatedAt: '2027-02-03T10:15:30+01:00',
      ),
      sha256.convert(utf8.encode(literal)).toString().toUpperCase(),
    );
  });

  test('the timestamp carries the offset the huella hashes', () {
    final stamp = verifactuTimestamp(_at);
    expect(stamp, matches(RegExp(r'^2027-02-03T10:15:30[+-]\d\d:\d\d$')));
  });

  test('three records chain, and a tampered middle amount breaks it', () {
    final chain = _chain();
    expect(chain[1].previousHuella, chain[0].huella);
    expect(chain[2].previousHuella, chain[1].huella);
    expect(verifactuChainHolds(chain), isTrue);

    final tampered = [
      chain[0],
      chain[1].withTotals(grandTotal: '1.00'),
      chain[2],
    ];
    expect(verifactuChainHolds(tampered), isFalse);
    expect(
      verifactuChainHolds([chain[0], chain[2]]),
      isFalse,
      reason: 'a removed record leaves its successor naming a stranger',
    );
  });

  test('a credit note is an R1 stated with negative amounts', () {
    final r = verifactuRecordFor(
      invoice: _invoice('A-1', credit: true),
      seller: _seller,
      buyer: _buyer,
      previousHuella: '',
      generatedAt: _at,
    );
    expect(r.type, 'R1');
    expect(r.taxTotal, '-21.00');
    expect(r.grandTotal, '-121.00');
  });

  test('a buyer without any tax id makes it a simplified F2', () {
    final r = verifactuRecordFor(
      invoice: _invoice('F-9'),
      seller: _seller,
      buyer: const InvoiceParty(name: 'Ana', country: 'ES'),
      previousHuella: '',
      generatedAt: _at,
    );
    expect(r.type, 'F2');
    expect(r.buyerNif, isEmpty);
  });

  test('the QR URL encodes the four fields the AEAT checks', () {
    final r = _chain().first;
    final url = verifactuQrUrl(r);
    expect(url.host, 'www2.agenciatributaria.gob.es');
    expect(url.path, '/wlpl/TIKE-CONT/ValidarQR');
    expect(url.queryParameters, {
      'nif': 'B12345674',
      'numserie': 'F-1',
      'fecha': '03-02-2027',
      'importe': '121.00',
    });
    expect(verifactuQrUrl(r, test: true).host, 'prewww2.aeat.es');

    final slashed = verifactuQrUrl(r.withTotals());
    expect(slashed.toString(), contains('numserie=F-1'));
    final odd = verifactuQrUrl(
      const VerifactuRecord(
        issuerNif: 'B1',
        number: '12345678/G33',
        issueDate: '01-01-2024',
        type: 'F1',
        taxTotal: '0.00',
        grandTotal: '1.00',
        previousHuella: '',
        generatedAt: '',
        huella: '',
      ),
    );
    expect(odd.toString(), contains('numserie=12345678%2FG33'));
  });

  test('the legend is the fixed Spanish wording', () {
    expect(verifactuLegend, 'VERI*FACTU');
    expect(
      verifactuMention,
      'Factura verificable en la sede electrónica de la AEAT',
    );
  });

  test(
    'the record XML chains the first record and names the previous after',
    () {
      final chain = _chain();
      XmlDocument parse(VerifactuRecord r) => XmlDocument.parse(
        verifactuRecordXml(r, issuerName: 'Espacio Test SL'),
      );
      String text(XmlDocument d, String name) =>
          d.findAllElements('sum1:$name').first.innerText;

      final first = parse(chain[0]);
      expect(first.rootElement.name.qualified, 'sum1:RegistroAlta');
      expect(text(first, 'PrimerRegistro'), 'S');
      expect(first.findAllElements('sum1:RegistroAnterior'), isEmpty);
      expect(text(first, 'Huella'), chain[0].huella);
      expect(text(first, 'TipoHuella'), '01');
      expect(
        text(first, 'NIF'),
        'A87654321',
        reason: 'a Spanish buyer is named by its NIF',
      );
      expect(text(first, 'CalificacionOperacion'), 'S1');
      expect(text(first, 'CuotaRepercutida'), '21.00');

      final second = parse(chain[1]);
      expect(second.findAllElements('sum1:PrimerRegistro'), isEmpty);
      final previous = second.findAllElements('sum1:RegistroAnterior').single;
      expect(
        previous.findElements('sum1:NumSerieFactura').single.innerText,
        'F-1',
      );
      expect(
        previous.findElements('sum1:Huella').single.innerText,
        chain[0].huella,
      );
    },
  );
}
