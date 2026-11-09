// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the Spanish registers through the host's own seam, `VatRegisterFiles`:
// the file names and the bytes the add-on hands back, against the goldens the
// writers were pinned with before they moved (`test/parity/golden/es_register`),
// and the refusals the host turns into the filing file's own.
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/vat_register_files.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../parity/es_register_fixtures.dart' as fx;
import 'es_register_support.dart';

const _golden = 'test/parity/golden/es_register';

VatFilingParty _party({String vatId = 'ESB12345678', String country = 'ES'}) =>
    VatFilingParty(
      countryCode: country,
      name: 'Espacio Coworking, S.L.',
      street: '',
      postalCode: '',
      city: '',
      vatId: vatId,
      legalId: '',
    );

VatRegisterFiles _files({
  VatFilingParty? party,
  TaxReferenceSet? reference,
  bool empty = false,
}) => VatRegisterFiles(
  party: party ?? _party(),
  invoices: () async => empty ? const [] : fx.documents(),
  declarations: () async => const [],
  reference: reference ?? ActiveTaxReference.current,
);

Map<String, List<int>> _parts(List<int> zip) => {
  for (final f in ZipDecoder().decodeBytes(zip).files)
    f.name: f.content as List<int>,
};

String _text(String name) => File('$_golden/$name').readAsStringSync();

void main() {
  test(
    'the libro: the AEAT file name, and the workbook of the pinned sheet',
    () async {
      final file = await _files().esLibro(
        end: DateTime(2026, 12, 31),
        activity: 'A038612',
      );
      expect(file, isNotNull);
      expect(file!.fileName, '2026B12345678EEspacio Coworking, S.L..xlsx');
      final sheet = esLibroExpedidas(
        registerDocuments(
          fx.documents(),
          from: DateTime.utc(2026),
          to: DateTime.utc(2027),
        ),
        activity: 'A038612',
        reference: ActiveTaxReference.current,
      );
      expect(fx.sheetText(sheet), _text('libro_year.txt'));
      // the zip stamps its entries with the clock: compare what they hold
      expect(_parts(file.bytes), _parts(buildXlsx([sheet])));
    },
  );

  test('the SII message: the pinned bytes, named by its first day', () async {
    final file = await _files().esSii(
      start: DateTime(2026),
      end: DateTime(2026, 12, 31),
    );
    expect(file!.fileName, 'sii-facturas-emitidas-2026-01-01.xml');
    expect(utf8.decode(file.bytes), _text('sii_year.xml'));
  });

  test('the modelo 347: the pinned list, named by its year', () async {
    final file = await _files().es347(year: 2026, immediateSupply: false);
    expect(file!.fileName, 'modelo-347-2026.csv');
    expect(utf8.decode(file.bytes), _text('modelo347_2026.csv'));
  });

  test('a reference with no modelo347 row writes no 347', () async {
    final without = TaxReferenceSet([
      for (final row in ActiveTaxReference.current.rows)
        if (row.key != 'modelo347') row,
    ]);
    expect(
      await _files(reference: without)
          .es347(year: 2026, immediateSupply: false),
      isNull,
    );
  });

  test('a space on the SII is refused a 347, in the filing file\'s words', () {
    expect(
      _files().es347(year: 2026, immediateSupply: true),
      throwsA(
        isA<VatFilingFileException>().having(
          (e) => e.problem,
          'problem',
          VatFilingFileProblem.exoneratedBySii,
        ),
      ),
    );
  });

  test('the SII message of a space whose NIF is not one is refused', () {
    expect(
      _files(party: _party(vatId: 'ES12'))
          .esSii(start: DateTime(2026), end: DateTime(2026, 12, 31)),
      throwsA(
        isA<VatFilingFileException>().having(
          (e) => e.problem,
          'problem',
          VatFilingFileProblem.vatNumber,
        ),
      ),
    );
  });

  test('a period with nothing to write, or a country with no registers, writes nothing', () async {
    expect(
      await _files(empty: true)
          .esLibro(end: DateTime(2026, 12, 31), activity: ''),
      isNull,
    );
    expect(
      await _files(party: _party(country: 'DE'))
          .esSii(start: DateTime(2026), end: DateTime(2026, 12, 31)),
      isNull,
    );
  });
}
