// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the Italian add-on writes the LIPE as the XML of the fornitura IVP18
// from the context it is given: one Modulo for the month or the quarter, VP2-VP6
// from the boxes, VP14 as VP6 leaves it (to pay or to carry, never negative),
// the declarant only when named (both a codice fiscale and a codice carica).
// Its refusals are stable codes in the order the writer always had them,
// `build` never skips them, and it carries its own descriptor. (The bytes of the
// whole product path are pinned by the application's parity goldens and the
// published schema.)
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

FilingBox _vp(String key, int cents) => FilingBox(
  code: key,
  label: key,
  netCents: cents,
  vatCents: cents,
  baseKey: key,
  taxKey: '',
  hasTax: false,
);

const _declarant = FilingFacts(
  declarantFiscalCode: 'RSSMRA80A01H501U',
  declarantRole: '1',
);

FilingContext _context({
  DateTime? start,
  DateTime? end,
  String vatId = 'IT01234567890',
  String fiscalCode = '01234567890',
  FilingFacts facts = _declarant,
  List<FilingBox>? boxes,
  String country = 'IT',
}) => FilingContext(
  periodStart: start ?? DateTime(2026, 4),
  periodEnd: end ?? DateTime(2026, 6, 30),
  currency: 'EUR',
  lines: const [],
  boxes:
      boxes ??
      [
        _vp('VP2', 150000),
        _vp('VP3', 30000),
        _vp('VP4', 22000),
        _vp('VP5', 6600),
        _vp('VP6_1', 15400),
      ],
  generatedAt: DateTime.utc(2026, 10, 2, 12),
  facts: facts,
  party: FilingParty(
    countryCode: country,
    name: 'Spazio Srl',
    street: '',
    postalCode: '',
    city: '',
    vatId: vatId,
    legalId: fiscalCode,
  ),
);

XmlDocument _xml(FilingContext c) {
  const add = ItVatFilingContribution();
  return XmlDocument.parse(
    utf8.decode(add.build(add.validate(c).filing!).bytes),
  );
}

String _text(XmlDocument d, String name) =>
    d.findAllElements(name).single.innerText;

void main() {
  const add = ItVatFilingContribution();

  test('one Modulo of the quarter, VP2-VP6 and VP14', () {
    final xml = _xml(_context());
    expect(_text(xml, 'iv:CodiceFornitura'), 'IVP18');
    expect(_text(xml, 'iv:CodiceFiscale'), '01234567890');
    expect(_text(xml, 'iv:PartitaIVA'), '01234567890');
    expect(_text(xml, 'iv:AnnoImposta'), '2026');
    expect(_text(xml, 'iv:CFDichiarante'), 'RSSMRA80A01H501U');
    expect(_text(xml, 'iv:CodiceCaricaDichiarante'), '1');
    expect(_text(xml, 'iv:Trimestre'), '2');
    expect(xml.findAllElements('iv:Mese'), isEmpty);
    expect(_text(xml, 'iv:TotaleOperazioniAttive'), '1500,00');
    expect(_text(xml, 'iv:IvaDovuta'), '154,00');
    expect(_text(xml, 'iv:ImportoDaVersare'), '154,00');
  });

  test('a month carries Mese, a credit carries ImportoACredito', () {
    final xml = _xml(
      _context(
        start: DateTime(2026, 5),
        end: DateTime(2026, 5, 31),
        boxes: [_vp('VP6_2', 4050)],
        facts: const FilingFacts(),
      ),
    );
    expect(_text(xml, 'iv:Mese'), '5');
    expect(xml.findAllElements('iv:Trimestre'), isEmpty);
    expect(_text(xml, 'iv:ImportoACredito'), '40,50');
    expect(xml.findAllElements('iv:ImportoDaVersare'), isEmpty);
    expect(
      xml.findAllElements('iv:CFDichiarante'),
      isEmpty,
      reason: 'no declarant is named, none is written',
    );
  });

  test('what the file cannot say refuses it, in the writer\'s order', () {
    String? code(FilingContext c) {
      final r = add.validate(c);
      return r.filing == null ? r.result.codes.single : null;
    }

    expect(
      code(_context(start: DateTime(2026), end: DateTime(2026, 12, 31))),
      'period',
    );
    expect(code(_context(vatId: 'IT123')), 'vatNumber');
    expect(code(_context(fiscalCode: '')), 'fiscalCode');
    expect(
      code(
        _context(
          facts: const FilingFacts(declarantFiscalCode: 'RSSMRA80A01H501U'),
        ),
      ),
      'declarant',
      reason: 'a codice fiscale without a codice carica',
    );
    expect(
      code(_context(facts: const FilingFacts(declarantRole: '99'))),
      'declarant',
    );
    // period, then partita IVA, then codice fiscale
    expect(
      code(
        _context(
          start: DateTime(2026),
          end: DateTime(2026, 12, 31),
          vatId: 'IT1',
          fiscalCode: '',
        ),
      ),
      'period',
    );
    expect(code(_context(vatId: 'IT1', fiscalCode: '')), 'vatNumber');
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(vatId: 'IT1'))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'FR'))),
      throwsStateError,
    );
  });

  test('the artifact: name, media type, digest, provenance', () {
    final artifact = add.build(add.validate(_context()).filing!);
    expect(artifact.fileName, 'lipe-2026-04-01.xml');
    expect(artifact.mediaType, 'application/xml');
    expect(artifact.sha256, hasLength(64));
    expect(artifact.provenance['capability_id'], 'vat_filing.IT');
    expect(artifact.provenance['module_id'], 'it.vat_filing');
    expect(
      artifact.provenance['contract_version'],
      jurisdictionContractVersion,
    );
  });
}
