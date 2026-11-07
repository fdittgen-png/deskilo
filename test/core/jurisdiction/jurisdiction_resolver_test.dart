// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 -- the resolver chooses the installed add-on of the workspace's
// country and REFUSES, explicitly, when there is none, the country is missing,
// two add-ons claim it, or the add-on speaks another contract version. It
// never falls back to a country: France is not the answer for a space in
// Norway.
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_vat_filing.dart';

CapabilityResolution _resolve(
  String? country, [
  List<VatFilingContribution>? installed,
]) => resolveCapability(
  JurisdictionOperation.vatFiling,
  LegalContext(countryCode: country),
  installed ?? installedVatFilings,
);

FakeVatFilingContribution _fake(
  String country, {
  String contract = jurisdictionContractVersion,
}) => FakeVatFilingContribution(country, contractVersion: contract);

void main() {
  test('each installed country resolves to its own add-on', () {
    for (final country in ['DE', 'FR', 'GB', 'CH', 'CA', 'ES', 'IT']) {
      final r = _resolve(country);
      expect(r, isA<Resolved>(), reason: country);
      expect((r as Resolved).country, country);
    }
  });

  test(
    'the spelling of the context does not matter: case, spaces, UK for GB',
    () {
      expect((_resolve(' de ') as Resolved).country, 'DE');
      expect((_resolve('UK') as Resolved).country, 'GB');
    },
  );

  test('a missing country is refused as missing, not defaulted', () {
    for (final c in [null, '', '   ']) {
      expect(
        (_resolve(c) as Refused).kind,
        RefusalKind.missingJurisdiction,
        reason: '"$c"',
      );
    }
  });

  test('a country with no add-on is refused, never given the French file', () {
    for (final c in ['ZZ', 'NO', 'US', 'XX', 'FRA']) {
      expect(
        (_resolve(c) as Refused).kind,
        RefusalKind.unknownJurisdiction,
        reason: c,
      );
    }
  });

  test('two add-ons for one country are a conflict, and the host does not '
      'pick one', () {
    final r = _resolve('DE', [_fake('DE'), _fake('DE'), _fake('FR')]);
    expect((r as Refused).kind, RefusalKind.conflictingJurisdiction);
    expect(
      _resolve('FR', [_fake('DE'), _fake('DE'), _fake('FR')]),
      isA<Resolved>(),
    );
  });

  test('an add-on written against another contract version is refused', () {
    final r = _resolve('DE', [_fake('DE', contract: '0')]);
    expect((r as Refused).kind, RefusalKind.contractMismatch);
  });

  test('nothing installed refuses everything', () {
    expect(
      (_resolve('DE', const []) as Refused).kind,
      RefusalKind.unknownJurisdiction,
    );
  });

  test('every installed add-on declares the current contract version, a '
      'non-empty implementation and format version, and a unique capability '
      'id', () {
    final ids = <String>{};
    for (final c in installedVatFilings) {
      final d = c.descriptor;
      expect(
        d.contractVersion,
        jurisdictionContractVersion,
        reason: d.moduleId,
      );
      expect(d.implementationVersion, isNotEmpty, reason: d.moduleId);
      expect(d.formatVersion, isNotEmpty, reason: d.moduleId);
      expect(d.moduleId, isNotEmpty);
      expect(
        ids.add(d.capabilityId),
        isTrue,
        reason: 'duplicate ${d.capabilityId}',
      );
      expect(d.capabilityId, startsWith('vat_filing.'));
    }
  });
}
