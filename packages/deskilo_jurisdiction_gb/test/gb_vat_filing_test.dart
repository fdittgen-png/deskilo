// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the British add-on writes the nine MTD boxes as one CSV row under
// HMRC's field names (pence in boxes 1-5, whole pounds in 6-9) from the boxes
// of its context, refuses a registration number with fewer than nine digits as
// a stable code, and carries its own descriptor. The helpers it exports are
// the ones the application's "submit through MTD" screen reads.
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:test/test.dart';

const _boxes = [
  FilingBox(
    code: '1',
    label: 'x',
    netCents: 0,
    vatCents: 20020,
    hasBase: false,
    taxKey: 'vatDueSales',
  ),
  FilingBox(
    code: '3',
    label: 'x',
    netCents: 0,
    vatCents: 20020,
    hasBase: false,
    taxKey: 'totalVatDue',
  ),
  FilingBox(
    code: '4',
    label: 'x',
    netCents: 0,
    vatCents: 13894,
    hasBase: false,
    taxKey: 'vatReclaimedCurrPeriod',
  ),
  FilingBox(
    code: '5',
    label: 'x',
    netCents: 0,
    vatCents: 6126,
    hasBase: false,
    taxKey: 'netVatDue',
  ),
  FilingBox(
    code: '6',
    label: 'x',
    netCents: 120198,
    vatCents: 0,
    hasTax: false,
    baseKey: 'totalValueSalesExVAT',
  ),
  FilingBox(
    code: '7',
    label: 'x',
    netCents: 69468,
    vatCents: 0,
    hasTax: false,
    baseKey: 'totalValuePurchasesExVAT',
  ),
];

FilingContext _context({
  String vatId = 'GB 123 4567 89',
  String country = 'GB',
}) => FilingContext(
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 9, 30),
  currency: 'GBP',
  lines: const [],
  boxes: _boxes,
  generatedAt: DateTime.utc(2026, 10, 2, 12),
  party: FilingParty(
    countryCode: country,
    name: 'Desks Ltd',
    street: '1 High St',
    postalCode: 'N1 1AA',
    city: 'London',
    vatId: vatId,
    legalId: '12345678',
  ),
);

void main() {
  const add = GbVatFilingContribution();

  test('one row: the nine boxes under HMRC field names', () {
    final artifact = add.build(add.validate(_context()).filing!);
    final text = utf8.decode(artifact.bytes);
    expect(text, endsWith('\r\n'));
    final rows = text.trim().split('\r\n');
    expect(rows, hasLength(2));
    final head = rows[0].split(',');
    final row = rows[1].split(',');
    final byName = {for (var i = 0; i < head.length; i++) head[i]: row[i]};
    expect(head.take(3), ['vrn', 'periodStart', 'periodEnd']);
    expect(head.skip(3), mtdBoxFields);
    expect(byName['vrn'], '123456789');
    expect(byName['periodStart'], '2026-07-01');
    expect(byName['periodEnd'], '2026-09-30');
    expect(byName['vatDueSales'], '200.20');
    expect(byName['vatDueAcquisitions'], '0.00', reason: 'absent = zero');
    expect(byName['vatReclaimedCurrPeriod'], '138.94');
    expect(byName['netVatDue'], '61.26');
    expect(
      byName['totalValueSalesExVAT'],
      '1201',
      reason: 'whole pounds, the pence dropped',
    );
    expect(byName['totalValuePurchasesExVAT'], '694');
    expect(byName['totalAcquisitionsExVAT'], '0');
  });

  test('without nine digits there is no file; XI and GB prefixes are read', () {
    expect(add.validate(_context(vatId: 'GB12')).result.codes, ['vatNumber']);
    expect(add.validate(_context(vatId: '')).filing, isNull);
    expect(add.validate(_context(vatId: 'XI123456789')).filing, isNotNull);
    expect(add.validate(_context(vatId: '123456789')).filing, isNotNull);
  });

  test(
    'build validates again; UK is read as GB; a foreign filing is refused',
    () {
      expect(
        () => add.build(ValidatedFiling(_context(vatId: '1'))),
        throwsStateError,
      );
      expect(
        () => add.build(ValidatedFiling(_context(country: 'FR'))),
        throwsStateError,
      );
      expect(
        add.build(add.validate(_context(country: 'UK')).filing!).fileName,
        'mtd-vat-return-2026-07-01.csv',
      );
    },
  );

  test('the box helpers: pence and whole pounds, as the screen reads them', () {
    final cents = mtdBoxCentsOf(_boxes);
    expect(cents['totalValueSalesExVAT'], 120100);
    expect(mtdBoxText('vatDueSales', -1205), '-12.05');
    expect(mtdBoxText('totalValueSalesExVAT', 120100), '1201');
    expect(mtdBoxIsWhole('totalAcquisitionsExVAT'), isTrue);
    expect(mtdBoxIsWhole('netVatDue'), isFalse);
  });

  test('the artifact: media type, digest, provenance', () {
    final artifact = add.build(add.validate(_context()).filing!);
    expect(artifact.mediaType, 'text/csv');
    expect(artifact.sha256, hasLength(64));
    expect(artifact.provenance['capability_id'], 'vat_filing.GB');
    expect(artifact.provenance['module_id'], 'gb.vat_filing');
  });
}
