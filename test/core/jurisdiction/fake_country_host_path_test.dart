// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the sixth-country proof. Adding a country's VAT filing needs a new
// package, a composition registration, reference data and evidence -- and NO
// edit to the money feature's business decisions. A country that exists only in
// this test is registered in a TEST composition and saved through the host's
// own seam (`SaveVatFilingFile`, the one the screen calls): the expected bytes
// reach the file saver, a refusal saves nothing, and the production
// composition refuses the same country.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/application/save_vat_filing_file.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vat_filing.dart';

const _party = VatFilingParty(
  countryCode: 'ZZ',
  name: 'Fakeland Space',
  street: '1 Test Road',
  postalCode: '0000',
  city: 'Testville',
  vatId: 'ZZ123',
  legalId: '',
);

VatDeclaration _declaration() => VatDeclaration(
  id: 'd',
  workspaceId: 'w',
  periodStart: DateTime(2026, 3),
  periodEnd: DateTime(2026, 3, 31),
  status: 'prepared',
  lines: [
    const VatDeclarationLine(
      percent: 10,
      grossCents: 11000,
      netCents: 10000,
      vatCents: 1000,
      invoiceCount: 1,
    ),
  ],
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: DateTime.utc(2026, 4),
);

class _Saver {
  final calls = <({Uint8List bytes, String fileName})>[];

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls.add((bytes: bytes, fileName: fileName));
    return 'saved';
  }
}

SaveVatFilingFile _save(_Saver saver, {bool withFake = false}) =>
    SaveVatFilingFile(
      saver.call,
      () => DateTime.utc(2026, 4, 2),
      party: _party,
      installed: withFake
          ? [...installedVatFilings, const FakeVatFilingContribution('ZZ')]
          : null,
    );

void main() {
  test('a country registered only in a test composition is saved through the '
      'host path, byte for byte', () async {
    final saver = _Saver();
    final save = _save(saver, withFake: true);
    expect(save.country, 'ZZ');
    final where = await save(
      _declaration(),
      facts: const VatFilingFacts(taxNumber: 'TN-1'),
    );
    expect(where, 'saved');
    expect(saver.calls, hasLength(1));
    expect(saver.calls.single.fileName, 'fake-zz.txt');
    expect(
      utf8.decode(saver.calls.single.bytes),
      'FAKE ZZ 2026-03-01 1 TN-1\n',
    );
  });

  test(
    'its refusal is the host\'s own: the stable problem, nothing saved',
    () {
      final saver = _Saver();
      expect(
        () => _save(saver, withFake: true)(_declaration()),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.taxNumber,
          ),
        ),
      );
      expect(saver.calls, isEmpty);
    },
  );

  test('the production composition refuses it: there is no file for the '
      'country, nothing is saved', () {
    final saver = _Saver();
    final save = _save(saver);
    expect(save.country, isNull);
    expect(
      () =>
          save(_declaration(), facts: const VatFilingFacts(taxNumber: 'TN-1')),
      throwsUnsupportedError,
    );
    expect(saver.calls, isEmpty);
  });

  test('the production composition is exactly the seven countries, one '
      'add-on each, on the current contract', () {
    expect(
      installedVatFilings.map((c) => c.descriptor.capabilityId).toList()
        ..sort(),
      [
        for (final c in ['CA', 'CH', 'DE', 'ES', 'FR', 'GB', 'IT'])
          'vat_filing.$c',
      ],
    );
  });
}
