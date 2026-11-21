// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3932 -- the Spanish add-on builds the sandbox test record of the AEAT's
// Verifactu service from ONE preview document: the SOAP message of a record on
// a chain of its own, refused without the keeper's tax id, and nothing when it
// is not given exactly one document.
import 'dart:convert' show utf8;

import 'package:deskilo/core/jurisdiction/installed_registers.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter_test/flutter_test.dart';

RegisterDocument _preview() => RegisterDocument(
  number: 'TEST-20271101090000',
  issuedAt: DateTime(2027, 11),
  currency: 'EUR',
  totalCents: 12100,
  vatTotals: const [
    RegisterVatLine(
      percent: 21,
      category: 'S',
      grossCents: 12100,
      netCents: 10000,
      vatCents: 2100,
    ),
  ],
  buyerParty: const RegisterParty(
    name: 'Cliente SA',
    country: 'ES',
    vatId: 'A58818501',
  ),
);

RegisterContext _context(List<RegisterDocument> docs, {String vat = 'ESB12345674'}) =>
    RegisterContext(
      documents: docs,
      from: DateTime(2027, 11, 1, 9),
      to: DateTime(2027, 11, 1, 9),
      sellerVatId: vat,
      sellerName: 'Cowork Sevilla SL',
    );

void main() {
  final es = registersOf('ES')!;

  test('the test record is the SOAP message of one record, on its own chain', () {
    final file = es.generate('esVerifactuTest', _context([_preview()]))!;
    final xml = utf8.decode(file.bytes);
    expect(file.mediaType, 'application/xml');
    expect(file.fileName, 'verifactu-test-TEST-20271101090000.xml');
    expect(xml, contains('Envelope'));
    expect(xml, contains('TEST-20271101090000'));
    expect(xml, contains('B12345674'));
    expect(xml, contains('PrimerRegistro'));
    expect('RegistroAlta'.allMatches(xml).length, greaterThanOrEqualTo(2));
  });

  test('without the keeper\'s tax id it is refused, and nothing is written', () {
    expect(
      () => es.generate('esVerifactuTest', _context([_preview()], vat: ' ')),
      throwsA(
        isA<RegisterRefusal>().having(
          (e) => e.problem,
          'problem',
          RegisterProblem.vatNumber,
        ),
      ),
    );
  });

  test('it takes exactly one document', () {
    expect(es.generate('esVerifactuTest', _context([])), isNull);
    expect(
      es.generate('esVerifactuTest', _context([_preview(), _preview()])),
      isNull,
    );
  });
}
