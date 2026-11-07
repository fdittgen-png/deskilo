// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the Swiss add-on writes the MWST-Abrechnung as eCH-0217 XML from the
// context it is given: the effective method with turnover net, the rates, the
// input tax split between material/services and investments, `payableTax`
// computed the way the standard prescribes, the supplies opted for and the
// acquisition tax per rate. It refuses an invalid UID as a stable code, `build`
// never skips that, and it carries its own descriptor. (The bytes of the whole
// product path are pinned by the application's parity goldens, the XSD
// validation by `tool/vat_filing/validate.sh`.)
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

FilingLine _line(
  double percent,
  int net,
  int vat, {
  String category = 'S',
  String direction = 'output',
  int opted = 0,
}) => FilingLine(
  percent: percent,
  netCents: net,
  vatCents: vat,
  grossCents: net + vat,
  invoiceCount: 1,
  category: category,
  direction: direction,
  optedNetCents: opted,
);

FilingContext _context({
  List<FilingLine>? lines,
  String uid = 'CHE-109.322.551 MWST',
  bool onReceipts = false,
  String country = 'CH',
}) => FilingContext(
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 9, 30),
  currency: 'CHF',
  number: 'MWST-1',
  lines:
      lines ??
      [
        _line(8.1, 100049, 8104),
        _line(2.6, 20000, 520),
        _line(0, 20050, 0, category: 'E'),
        _line(0, 5000, 0, category: 'G'),
        _line(8.1, 6000, 486, direction: 'input'),
        _line(8.1, 3000, 243, direction: 'input', category: 'asset'),
      ],
  generatedAt: DateTime.utc(2026, 10, 13, 8, 5, 9),
  party: FilingParty(
    countryCode: country,
    name: 'Cowork AG',
    street: '',
    postalCode: '',
    city: '',
    vatId: uid,
    legalId: '',
    onReceipts: onReceipts,
  ),
);

XmlElement _root(FilingContext c) {
  const add = ChVatFilingContribution();
  return XmlDocument.parse(
    utf8.decode(add.build(add.validate(c).filing!).bytes),
  ).rootElement;
}

void main() {
  const add = ChVatFilingContribution();

  test('the declaration: header, turnover, the rates, the tax to pay', () {
    final root = _root(_context());
    expect(root.name.local, 'VATDeclaration');
    expect(root.getAttribute('xmlns'), 'http://www.ech.ch/xmlns/eCH-0217/2');
    final general = root.getElement('generalInformation')!;
    expect(general.getElement('uid')!.innerText, 'CHE109322551');
    expect(general.getElement('organisationName')!.innerText, 'Cowork AG');
    expect(
      general.getElement('generationTime')!.innerText,
      '2026-10-13T08:05:09',
    );
    expect(general.getElement('reportingPeriodFrom')!.innerText, '2026-07-01');
    expect(general.getElement('reportingPeriodTill')!.innerText, '2026-09-30');
    expect(general.getElement('formOfReporting')!.innerText, '1');
    expect(general.getElement('businessReferenceId')!.innerText, 'MWST-1');
    final method = root.getElement('effectiveReportingMethod')!;
    expect(method.getElement('inputTaxMaterialAndServices')!.innerText, '4.86');
    expect(method.getElement('inputTaxInvestments')!.innerText, '2.43');
    // 8.1 % of 1000.49 + 2.6 % of 200.00 - 4.86 - 2.43, summed unrounded.
    expect(root.getElement('payableTax')!.innerText, '78.95');
  });

  test('a space on the received consideration says so', () {
    final root = _root(_context(onReceipts: true));
    expect(
      root
          .getElement('generalInformation')!
          .getElement('formOfReporting')!
          .innerText,
      '2',
    );
  });

  test('205 is `opted` and 383 one `acquisitionTax` per rate, its tax in '
      'payableTax; an acquisition is no consideration', () {
    final root = _root(
      _context(
        lines: [
          _line(8.1, 1600000, 129600, opted: 1000000),
          _line(8.1, 120000, 9720, category: 'acquisition'),
          _line(2.6, 10000, 260, category: 'acquisition'),
          _line(8.1, 120000, 8910, direction: 'input'),
        ],
      ),
    );
    final method = root.getElement('effectiveReportingMethod')!;
    expect(method.getElement('opted')!.innerText, '10000.00');
    expect(method.findElements('acquisitionTax'), hasLength(2));
    expect(
      root
          .getElement('turnoverComputation')!
          .getElement('totalConsideration')!
          .innerText,
      '16000.00',
      reason: 'the acquisitions are not turnover',
    );
  });

  test('a UID without a valid check digit gives no file', () {
    for (final uid in ['CHE-109.322.552', 'CHE-000.000.000', 'x', '']) {
      final r = add.validate(_context(uid: uid));
      expect(r.filing, isNull, reason: uid);
      expect(r.result.codes, ['uid'], reason: uid);
    }
    expect(add.validate(_context(uid: 'CHE109322551')).filing, isNotNull);
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(uid: 'CHE1'))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'FR'))),
      throwsStateError,
    );
  });

  test('the artifact: name, media type, digest, provenance', () {
    final artifact = add.build(add.validate(_context()).filing!);
    expect(artifact.fileName, 'mwst-abrechnung-2026-07-01.xml');
    expect(artifact.mediaType, 'application/xml');
    expect(artifact.sha256, hasLength(64));
    expect(artifact.provenance['capability_id'], 'vat_filing.CH');
    expect(artifact.provenance['module_id'], 'ch.vat_filing');
  });
}
