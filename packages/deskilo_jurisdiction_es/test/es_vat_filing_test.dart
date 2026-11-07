// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the Spanish add-on writes the Modelo 303 in the AEAT's fixed-width
// design from the context it is given: the envelope and the two pages at their
// lengths, the identification (the name in capitals, accents dropped, N-tilde
// kept), the casillas at their positions, a negative result compensated and
// carrying its N, and ISO-8859-1 bytes. Its refusals are stable codes in the
// order the writer always had them, `build` never skips them, and it carries its
// own descriptor. (The bytes of the whole product path are pinned by the
// application's parity goldens; the design itself is read row by row against
// the AEAT's spreadsheet by the application's layout test.)
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:test/test.dart';

FilingBox _box(String key, {int net = 0, int tax = 0, bool base = true}) =>
    FilingBox(
      code: key,
      label: key,
      netCents: net,
      vatCents: tax,
      hasBase: base,
      hasTax: !base,
      baseKey: base ? key : '',
      taxKey: base ? '' : key,
    );

FilingLine _line() => FilingLine(
  percent: 21,
  netCents: 100000,
  vatCents: 21000,
  grossCents: 121000,
  invoiceCount: 1,
);

FilingContext _context({
  DateTime? start,
  DateTime? end,
  List<FilingBox>? boxes,
  String vatId = 'ESB12345678',
  String name = 'Espacio Coworking Peñíscola, S.L.',
  FilingFacts facts = const FilingFacts(),
  String country = 'ES',
}) => FilingContext(
  periodStart: start ?? DateTime(2026, 7),
  periodEnd: end ?? DateTime(2026, 9, 30),
  currency: 'EUR',
  lines: [_line()],
  boxes:
      boxes ??
      [
        _box('07', net: 100000),
        _box('09', tax: 21000, base: false),
        _box('27', tax: 23000, base: false),
        _box('46', tax: 14600, base: false),
        _box('59', net: 30000),
      ],
  generatedAt: DateTime.utc(2026, 10, 2, 12),
  facts: facts,
  party: FilingParty(
    countryCode: country,
    name: name,
    street: '',
    postalCode: '',
    city: '',
    vatId: vatId,
    legalId: '',
  ),
);

String _at(String text, int position, int length) =>
    text.substring(position - 1, position - 1 + length);

String _text(FilingContext c) {
  const add = EsVatFilingContribution();
  return latin1.decode(add.build(add.validate(c).filing!).bytes);
}

void main() {
  const add = EsVatFilingContribution();

  test('the envelope, the identification and the casillas', () {
    final text = _text(_context());
    expect(text, startsWith('<T303020263T0000><AUX>'));
    expect(text, endsWith('</T303020263T0000>'));
    final aux = text.indexOf('</AUX>') + '</AUX>'.length;
    expect(aux, 328, reason: 'the content starts at position 329');
    final page01 = text.substring(aux, aux + 1581);
    final page03 = text.substring(aux + 1581, aux + 1581 + 1017);
    expect(page01, startsWith('<T30301000>'));
    expect(page03, startsWith('<T30303000>'));
    expect(_at(page01, 13, 1), 'I', reason: 'a result to pay');
    expect(_at(page01, 14, 9), 'B12345678');
    expect(_at(page01, 23, 80).trimRight(), 'ESPACIO COWORKING PEÑISCOLA S L');
    expect(_at(page01, 103, 4), '2026');
    expect(_at(page01, 107, 2), '3T');
    expect(_at(page01, 326, 17), '00000000000100000', reason: '[07] base');
    expect(_at(page01, 348, 17), '00000000000021000', reason: '[09] cuota');
    expect(_at(page01, 696, 17), '00000000000023000', reason: '[27]');
    expect(_at(page01, 1019, 17), '00000000000014600', reason: '[46]');
    expect(_at(page03, 12, 17), '00000000000030000', reason: '[59]');
    expect(_at(page03, 216, 5), '10000', reason: '[65] 100 %');
    expect(_at(page03, 408, 17), '00000000000014600', reason: '[71]');
  });

  test('a negative result is compensated and carries its N', () {
    final text = _text(
      _context(
        start: DateTime(2026, 4),
        end: DateTime(2026, 4, 30),
        boxes: [_box('46', tax: -1890, base: false)],
        facts: const FilingFacts(monthlyRefund: true),
      ),
    );
    final page01 = text.substring(328, 328 + 1581);
    expect(_at(page01, 13, 1), 'C');
    expect(_at(page01, 107, 2), '04');
    expect(_at(page01, 110, 1), '1', reason: 'REDEME');
    expect(_at(page01, 1019, 17), 'N0000000000001890');
  });

  test('the file is ISO-8859-1: N-tilde is one byte', () {
    final bytes = add.build(add.validate(_context()).filing!).bytes;
    expect(bytes, contains(0xD1));
    expect(bytes, isNot(contains(0xC3)), reason: 'no UTF-8 lead byte');
    expect(bytes.length, latin1.decode(bytes).length);
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
    expect(code(_context(vatId: 'ES12')), 'vatNumber');
    expect(
      code(
        _context(
          start: DateTime(2026, 10),
          end: DateTime(2026, 12, 31),
          facts: const FilingFacts(immediateSupply: true),
        ),
      ),
      'annualVolume',
    );
    expect(
      code(
        _context(
          boxes: [
            const FilingBox(
              code: 'x',
              label: 'no casilla',
              netCents: 1000,
              vatCents: 50,
            ),
          ],
        ),
      ),
      'unmappedBox',
    );
    expect(code(_context(boxes: [_box('07', net: -1000)])), 'negativeAmount');
    // the period is checked before the NIF, as the writer always did
    expect(
      code(
        _context(
          start: DateTime(2026),
          end: DateTime(2026, 12, 31),
          vatId: 'ES12',
        ),
      ),
      'period',
    );
  });

  test('build validates again: a hand-made or foreign filing is refused', () {
    expect(
      () => add.build(ValidatedFiling(_context(vatId: 'ES12'))),
      throwsStateError,
    );
    expect(
      () => add.build(ValidatedFiling(_context(country: 'FR'))),
      throwsStateError,
    );
  });

  test('the artifact: name, media type, digest, provenance', () {
    final artifact = add.build(add.validate(_context()).filing!);
    expect(artifact.fileName, 'modelo-303-2026-07-01.txt');
    expect(artifact.mediaType, contains('iso-8859-1'));
    expect(artifact.sha256, hasLength(64));
    expect(artifact.provenance['capability_id'], 'vat_filing.ES');
    expect(artifact.provenance['module_id'], 'es.vat_filing');
    expect(
      artifact.provenance['contract_version'],
      jurisdictionContractVersion,
    );
  });
}
