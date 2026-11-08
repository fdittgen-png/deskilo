// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 review -- the contract cannot be skipped: `build` validates again and
// refuses a filing its own `validate` would not issue (a hand-made one, or one
// made for another country's add-on), and a code the host does not know is a
// contract fault on the generic failure path, never an ArgumentError from an
// enum lookup.
import 'dart:typed_data';

import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/filing_context_builder.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/application/save_vat_filing_file.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter_test/flutter_test.dart';

VatFilingContribution _of(String country) => installedVatFilings.firstWhere(
  (c) => c.descriptor.capabilityId == 'vat_filing.$country',
);

const _party = VatFilingParty(
  countryCode: 'DE',
  name: 'Raum GmbH',
  street: 'Hauptstr. 1',
  postalCode: '10115',
  city: 'Berlin',
  vatId: 'DE123456789',
  legalId: 'HRB 1',
);

VatDeclaration _declaration(DateTime start, DateTime end) => VatDeclaration(
  id: 'd',
  workspaceId: 'w',
  periodStart: start,
  periodEnd: end,
  status: 'prepared',
  lines: const [],
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'EUR',
  invoiceCount: 0,
  createdAt: DateTime.utc(2026),
);

FilingContext _context(VatDeclaration d, {VatFilingParty party = _party}) =>
    filingContextOf(
      declaration: d,
      party: party,
      now: DateTime.utc(2026, 10, 2, 12),
      facts: const VatFilingFacts(taxNumber: '21/815/08150'), reference: ActiveTaxReference.current,);

/// A contribution that refuses with a code of its own.
class _Refusing implements VatFilingContribution {
  _Refusing(this.code);
  final String code;

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fake.vat_filing',
    implementationVersion: '1',
    contractVersion: jurisdictionContractVersion,
    formatVersion: 'x',
    capabilityId: 'vat_filing.DE',
  );

  @override
  Set<FilingSource> get requiredSources => const {};

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) =>
      (filing: null, result: ValidationResult.refused([ValidationIssue(code)]));

  @override
  GeneratedArtifact build(ValidatedFiling filing) => throw UnimplementedError();
}

void main() {
  test('build refuses a hand-made filing its own validate would refuse', () {
    final year = _context(_declaration(DateTime(2026), DateTime(2026, 12, 31)));
    expect(_of('DE').validate(year).filing, isNull);
    expect(() => _of('DE').build(ValidatedFiling(year)), throwsStateError);
  });

  test('build refuses a filing made for another country', () {
    final month = _context(
      _declaration(DateTime(2026, 3), DateTime(2026, 3, 31)),
    );
    final german = _of('DE').validate(month).filing!;
    expect(() => _of('FR').build(german), throwsStateError);
    expect(_of('DE').build(german).bytes, isNotEmpty);
  });

  test(
    'a code the host does not know takes the generic failure path',
    () async {
      final save = SaveVatFilingFile(
        ({required Uint8List bytes, required String fileName}) async => 'x',
        () => DateTime.utc(2026, 10, 2),
        party: _party,
        installed: [_Refusing('somethingNew')], reference: ActiveTaxReference.current,);
      final d = _declaration(DateTime(2026, 3), DateTime(2026, 3, 31));
      expect(() => save(d), throwsStateError);
      final known = SaveVatFilingFile(
        ({required Uint8List bytes, required String fileName}) async => 'x',
        () => DateTime.utc(2026, 10, 2),
        party: _party,
        installed: [_Refusing('taxNumber')], reference: ActiveTaxReference.current,);
      expect(
        () => known(d),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.taxNumber,
          ),
        ),
      );
    },
  );
}
