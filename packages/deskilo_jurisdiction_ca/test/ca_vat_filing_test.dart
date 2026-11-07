// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the Canadian add-on writes the GST34 lines then the FPZ-500 QST
// lines as one CSV with the business number formatted, bases and taxes as bare
// numbers, never quoted; it refuses a business number without its RT account as
// a stable code, `build` never skips that, and it carries its own descriptor.
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:test/test.dart';

FilingContext _context({
  String bn = '123456789rt0001',
  String country = 'CA',
  bool qst = true,
}) => FilingContext(
  periodStart: DateTime(2026, 7),
  periodEnd: DateTime(2026, 9, 30),
  currency: 'CAD',
  lines: const [],
  boxes: const [
    FilingBox(
      code: '101',
      label: 'Sales',
      netCents: 110000,
      vatCents: 0,
      hasTax: false,
    ),
    FilingBox(
      code: '105',
      label: 'Tax, "collected"',
      netCents: 0,
      vatCents: 5500,
      hasBase: false,
    ),
  ],
  extraBoxes: {
    if (qst)
      caQstFormName: const [
        FilingBox(
          code: '209',
          label: 'Net QST',
          netCents: 0,
          vatCents: 4988,
          hasBase: false,
        ),
      ],
  },
  generatedAt: DateTime.utc(2026, 10, 13, 12),
  party: FilingParty(
    countryCode: country,
    name: 'Espace',
    street: '',
    postalCode: '',
    city: '',
    vatId: bn,
    legalId: '',
  ),
);

void main() {
  const add = CaVatFilingContribution();

  String text(FilingContext c) =>
      utf8.decode(add.build(add.validate(c).filing!).bytes);

  test('the file: GST34 lines then FPZ-500, the business number formatted', () {
    final rows = text(_context()).trim().split('\r\n');
    expect(rows.first, startsWith('"return","business_number"'));
    expect(
      rows[1],
      '"GST34","123456789 RT0001","2026-07-01","2026-09-30",'
      '"101","Sales",1100.00,',
    );
    expect(
      rows[2],
      contains('"Tax, ""collected"""'),
      reason: 'text cells are quoted and escaped, numbers are not',
    );
    expect(
      rows.last,
      '"FPZ-500","123456789 RT0001","2026-07-01",'
      '"2026-09-30","209","Net QST",,49.88',
    );
  });

  test('without QST boxes there is no FPZ-500 part', () {
    expect(text(_context(qst: false)), isNot(contains('FPZ-500')));
  });

  test('a business number needs its RT account: a stable code, not a file', () {
    final r = add.validate(_context(bn: '123456789'));
    expect(r.filing, isNull);
    expect(r.result.codes, ['businessNumber']);
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(bn: '1'))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'FR'))),
      throwsStateError,
    );
  });

  test('the artifact: file name, media type, digest, provenance', () {
    final artifact = add.build(add.validate(_context()).filing!);
    expect(artifact.fileName, 'gst-hst-qst-return-2026-07-01.csv');
    expect(artifact.mediaType, 'text/csv');
    expect(artifact.sha256, hasLength(64));
    expect(artifact.provenance['capability_id'], 'vat_filing.CA');
  });
}
