// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3332 -- the French add-on writes the CA3 as an EDI-TVA interchange from the
// context it is given: a segment count that holds, released special
// characters, one LIN per box with a key and its amounts in whole euros. Its
// refusals are stable codes, `build` never skips them, and it carries its own
// descriptor. (The bytes of the whole product path are pinned by the
// application's parity goldens.)
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:test/test.dart';

const _boxes = [
  FilingBox(
    code: '07',
    label: 'x',
    netCents: 5000,
    vatCents: 0,
    hasTax: false,
    baseKey: '0201',
  ),
  FilingBox(
    code: '08',
    label: 'x',
    netCents: 100010,
    vatCents: 20002,
    baseKey: '0207',
    taxKey: '0207',
  ),
  FilingBox(
    code: '20',
    label: 'x',
    netCents: 0,
    vatCents: 3200,
    hasBase: false,
    taxKey: '0702',
  ),
  FilingBox(
    code: '28',
    label: 'x',
    netCents: 0,
    vatCents: 16800,
    hasBase: false,
    taxKey: '8901',
  ),
  FilingBox(code: 'NA', label: 'no key', netCents: 1, vatCents: 1),
];

FilingContext _context({
  String name = "L'Atelier + Co",
  String legalId = '123 456 789',
  String vatId = 'FR12123456789',
  String country = 'FR',
  String number = 'DECL-2026-0007',
}) => FilingContext(
  periodStart: DateTime(2026, 9),
  periodEnd: DateTime(2026, 9, 30),
  currency: 'EUR',
  lines: const [],
  boxes: _boxes,
  number: number,
  generatedAt: DateTime.utc(2026, 10, 2, 9, 30),
  party: FilingParty(
    countryCode: country,
    name: name,
    street: '1 rue de la Paix',
    postalCode: '34120',
    city: 'Pézenas',
    vatId: vatId,
    legalId: legalId,
  ),
);

String _text(FilingContext c) {
  final add = const FrVatFilingContribution();
  return utf8.decode(add.build(add.validate(c).filing!).bytes);
}

void main() {
  const add = FrVatFilingContribution();

  test('an envelope whose counts hold', () {
    final segments = _text(_context()).split('\n');
    expect(segments.first, "UNA:+.? '");
    expect(
      segments[1],
      "UNB+UNOC:3+123456789:ZZ+DGFIP:ZZ+261002:0930+DECL20260007'",
    );
    expect(segments.last, "UNZ+1+DECL20260007'");
    final unh = segments.indexWhere((s) => s.startsWith('UNH+'));
    final unt = segments.indexWhere((s) => s.startsWith('UNT+'));
    expect(segments[unt], "UNT+${unt - unh + 1}+1'");
    for (final s in segments.skip(1)) {
      expect(s.endsWith("'"), isTrue, reason: s);
    }
  });

  test('the declarant, released, and each box with a key with its amounts', () {
    final text = _text(_context());
    expect(text, contains("NAD+FR+123456789::107++L?'Atelier ?+ Co+"));
    expect(text, contains("RFF+VA:FR12123456789'"));
    expect(text, contains("DTM+194:20260901:102'"));
    expect(text, contains("DTM+206:20260930:102'"));
    expect(
      text,
      contains("LIN+1++07:0201:ZZ'\nMOA+125:50'\nLIN+2++08:0207:ZZ'"),
    );
    expect(text, contains("LIN+2++08:0207:ZZ'\nMOA+125:1000'\nMOA+124:200'"));
    expect(text, contains(":0702:ZZ'\nMOA+124:32'"));
    expect(text, contains(":8901:ZZ'\nMOA+124:168'"));
    expect(
      text,
      isNot(contains('LIN+5')),
      reason: 'a box with no key has no line',
    );
  });

  test('without a number the reference is the period', () {
    expect(_text(_context(number: '')), contains("+CA320260901'"));
  });

  test('the SIREN: the registration number, else an FR VAT number', () {
    expect(frenchSiren(legalId: '123 456 789 00012', vatId: ''), '123456789');
    expect(frenchSiren(legalId: '', vatId: 'FR12123456789'), '123456789');
    expect(frenchSiren(legalId: '', vatId: ''), '');
  });

  test('a SIREN has nine digits: a stable code, not a file', () {
    final r = add.validate(_context(legalId: '12', vatId: ''));
    expect(r.filing, isNull);
    expect(r.result.codes, ['taxNumber']);
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(legalId: '12', vatId: ''))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'DE'))),
      throwsStateError,
    );
  });

  test(
    'the artifact: UTF-8 bytes, media type, file name, digest, provenance',
    () {
      final artifact = add.build(add.validate(_context()).filing!);
      expect(artifact.fileName, 'edi-tva-ca3-2026-09-01.edi');
      expect(artifact.mediaType, 'application/edifact');
      expect(artifact.sha256, hasLength(64));
      expect(artifact.provenance['module_id'], 'fr.vat_filing');
      expect(artifact.provenance['capability_id'], 'vat_filing.FR');
      expect(
        artifact.provenance['contract_version'],
        jurisdictionContractVersion,
      );
      expect(utf8.decode(artifact.bytes), contains('Pézenas'));
    },
  );
}
