// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- what an accounting format declares about itself, behind its own
// contract: DATEV's chart is the German one, the FEC's the French plan
// comptable and its four journals; the writers read these, no country code or
// journal code is written in them. A wrong composition is a programming error.
import 'package:deskilo/core/jurisdiction/installed_accounting_formats.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherVersion extends AccountingFormatContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.format',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: 'x',
    capabilityId: 'accounting_format.datev',
  );

  @override
  String get formatId => 'datev';

  @override
  String get chartCountry => 'XX';
}

void main() {
  test('every installed declaration names its format in its capability id', () {
    final ids = <String>{};
    for (final c in installedAccountingFormats) {
      final d = c.descriptor;
      expect(
        d.contractVersion,
        accountingFormatContractVersion,
        reason: d.moduleId,
      );
      expect(d.capabilityId, 'accounting_format.${c.formatId}');
      expect(
        ids.add(d.capabilityId),
        isTrue,
        reason: 'one declaration per format',
      );
    }
    expect(ids, {'accounting_format.datev', 'accounting_format.fec'});
  });

  test('DATEV posts to the German chart, the FEC to the French one', () {
    expect(accountingFormatOf('datev').chartCountry, 'DE');
    expect(accountingFormatOf('fec').chartCountry, 'FR');
  });

  test('the FEC declares its four journals, DATEV none', () {
    final journals = accountingFormatOf('fec').journals;
    expect(
      {for (final e in journals.entries) e.key: e.value.code},
      {'sales': 'VE', 'bank': 'BQ', 'purchases': 'HA', 'misc': 'OD'},
    );
    expect(accountingFormatOf('datev').journals, isEmpty);
  });

  test('a format nobody declares is a composition fault, not a guess', () {
    expect(
      resolveAccountingFormat('sage50', installedAccountingFormats),
      isNull,
    );
    expect(() => accountingFormatOf('sage50'), throwsStateError);
  });

  test(
    'two declarations for one format, or a wrong contract version, are errors',
    () {
      expect(
        () => resolveAccountingFormat('datev', const [
          DeDatevFormat(),
          DeDatevFormat(),
        ]),
        throwsStateError,
      );
      expect(
        () => resolveAccountingFormat('datev', const [_OtherVersion()]),
        throwsStateError,
      );
    },
  );
}
