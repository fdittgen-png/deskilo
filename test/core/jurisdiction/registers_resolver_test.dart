// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- the registers of issued invoices a country's law asks, behind their
// own contract: Spain writes the libro, the SII message and the modelo 347;
// every other country none, and never another country's. A wrong composition
// is a programming error.
import 'package:deskilo/core/jurisdiction/installed_registers.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherVersion extends RegisterContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.registers',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: 'x',
    capabilityId: 'registers.ES',
  );

  @override
  Set<String> get kinds => const {};

  @override
  GeneratedArtifact? generate(String kind, RegisterContext context) => null;
}

void main() {
  test('every installed add-on declares the current contract and one country', () {
    final ids = <String>{};
    for (final c in installedRegisters) {
      final d = c.descriptor;
      expect(d.contractVersion, registersContractVersion, reason: d.moduleId);
      expect(d.capabilityId, startsWith('registers.'));
      expect(ids.add(d.capabilityId), isTrue, reason: 'one add-on per country');
    }
    expect(ids, {'registers.ES'});
  });

  test('the Spanish add-on writes the three registers, and declares the 347 line', () {
    final es = registersOf('ES')!;
    expect(es.kinds, {'esLibro', 'esSii', 'es347'});
    expect(registersOf('es'), same(es));
    expect(es.thresholdKey('es347'), 'modelo347');
    expect(es.thresholdKey('esLibro'), isNull);
    expect(es.thresholdKey('esSii'), isNull);
  });

  test('the registers the VAT filing add-on offers are the ones the registers add-on writes', () {
    expect(
      const EsVatFilingContribution().registers,
      registersOf('ES')!.kinds,
    );
  });

  test('a country with no add-on writes none, and never another\'s', () {
    for (final c in ['DE', 'IT', 'FR', '', '  ', 'XX']) {
      expect(registersOf(c), isNull, reason: c);
    }
  });

  test('an activity code is checked by the add-on that reads it', () {
    final es = registersOf('ES')!;
    expect(es.acceptsActivity('A038612'), isTrue);
    expect(es.acceptsActivity(''), isTrue);
    expect(es.acceptsActivity('X038612'), isFalse);
  });

  test('two add-ons for one country, or a wrong contract version, are errors', () {
    expect(
      () => resolveRegisters(
        const LegalContext(countryCode: 'ES'),
        const [EsRegisters(), EsRegisters()],
      ),
      throwsStateError,
    );
    expect(
      () => resolveRegisters(
        const LegalContext(countryCode: 'ES'),
        const [_OtherVersion()],
      ),
      throwsStateError,
    );
  });
}
