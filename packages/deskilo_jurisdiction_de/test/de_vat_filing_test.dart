// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the German add-on writes the UStVA as ELSTER XML from the context
// it is given: the Zeitraum (01-12 a month, 41-44 a quarter), the Steuernummer
// as digits, every Kennzahl the boxes carry (bases in whole euros, tax with
// cents, in numeric order). Its refusals are stable codes in the order the
// writer always had them, `build` never skips them, and it carries its own
// descriptor. (The bytes of the whole product path are pinned by the
// application's parity goldens.)
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

const _boxes = [
  FilingBox(
    code: '81',
    label: 'x',
    netCents: 100099,
    vatCents: 19019,
    baseKey: 'Kz81',
    taxKey: 'Kz81',
  ),
  FilingBox(
    code: '21',
    label: 'x',
    netCents: 20099,
    vatCents: 0,
    hasTax: false,
    baseKey: 'Kz21',
  ),
  FilingBox(
    code: '66',
    label: 'x',
    netCents: 0,
    vatCents: 13199,
    hasBase: false,
    taxKey: 'Kz66',
  ),
  FilingBox(
    code: '83',
    label: 'x',
    netCents: 0,
    vatCents: 5820,
    hasBase: false,
    taxKey: 'Kz83',
  ),
  FilingBox(code: '--', label: 'no key', netCents: 1, vatCents: 1),
];

FilingContext _context({
  DateTime? start,
  DateTime? end,
  String taxNumber = '21/815/08150',
  String country = 'DE',
}) => FilingContext(
  periodStart: start ?? DateTime(2026, 9),
  periodEnd: end ?? DateTime(2026, 9, 30),
  currency: 'EUR',
  lines: const [],
  boxes: _boxes,
  generatedAt: DateTime.utc(2026, 10, 2, 12),
  facts: FilingFacts(taxNumber: taxNumber),
  party: FilingParty(
    countryCode: country,
    name: 'Raum GmbH',
    street: 'Hauptstr. 1',
    postalCode: '10115',
    city: 'Berlin',
    vatId: 'DE123456789',
    legalId: '',
  ),
);

XmlDocument _xml(FilingContext c) {
  const add = DeVatFilingContribution();
  return XmlDocument.parse(
    utf8.decode(add.build(add.validate(c).filing!).bytes),
  );
}

void main() {
  const add = DeVatFilingContribution();

  test('a month: the period, the tax number and the filled Kennzahlen', () {
    final xml = _xml(_context());
    String text(String name) => xml.findAllElements(name).single.innerText;
    expect(xml.rootElement.name.local, 'Elster');
    expect(text('Jahr'), '2026');
    expect(text('Zeitraum'), '09');
    expect(text('Steuernummer'), '2181508150');
    expect(
      text('Kz81'),
      '190.19',
      reason: 'one key for base and tax: the tax is written last',
    );
    expect(text('Kz21'), '200', reason: 'a base in whole euros, cut');
    expect(text('Kz66'), '131.99', reason: 'a tax amount keeps its cents');
    expect(text('Kz83'), '58.20');
    expect(text('Erstellungsdatum'), '20261002');
    expect(
      xml.findAllElements('Anmeldungssteuern').single.getAttribute('art'),
      'UStVA',
    );
  });

  test('the Kennzahlen come in numeric order', () {
    final order = _xml(_context())
        .findAllElements('Umsatzsteuervoranmeldung')
        .single
        .childElements
        .map((e) => e.name.local)
        .toList();
    expect(order.skipWhile((n) => !n.startsWith('Kz')).toList(), [
      'Kz21',
      'Kz66',
      'Kz81',
      'Kz83',
    ]);
  });

  test('a quarter is 41-44', () {
    final c = _context(start: DateTime(2026, 7), end: DateTime(2026, 9, 30));
    expect(_xml(c).findAllElements('Zeitraum').single.innerText, '43');
  });

  test('a year is not a UStVA period, and the tax number is required', () {
    final year = add.validate(
      _context(start: DateTime(2026), end: DateTime(2026, 12, 31)),
    );
    expect(year.filing, isNull);
    expect(year.result.codes, ['period']);
    final none = add.validate(_context(taxNumber: '123'));
    expect(none.result.codes, ['taxNumber']);
    // the period is checked first, as the writer always did
    final both = add.validate(
      _context(
        start: DateTime(2026),
        end: DateTime(2026, 12, 31),
        taxNumber: '1',
      ),
    );
    expect(both.result.codes, ['period']);
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(taxNumber: '1'))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'FR'))),
      throwsStateError,
    );
  });

  test(
    'the artifact: UTF-8 bytes, media type, file name, digest, provenance',
    () {
      final artifact = add.build(add.validate(_context()).filing!);
      expect(artifact.fileName, 'ustva-2026-09-01.xml');
      expect(artifact.mediaType, 'application/xml');
      expect(artifact.sha256, hasLength(64));
      expect(artifact.provenance['module_id'], 'de.vat_filing');
      expect(artifact.provenance['capability_id'], 'vat_filing.DE');
      expect(
        artifact.provenance['contract_version'],
        jurisdictionContractVersion,
      );
    },
  );
}
