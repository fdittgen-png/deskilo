// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- what a country's yearly archive carries, behind its own contract
// (the FEC is an accounting file, not VAT, so it is not the VAT filing
// contract's business): the French archive carries the FEC, the Swiss one the
// procedures, GB/IE/CA/US the readable handover, every other country nothing
// beyond its documents -- never another country's members. A wrong composition
// is a programming error.
import 'package:deskilo/core/jurisdiction/installed_archives.dart';
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:flutter_test/flutter_test.dart';

class _OtherVersion extends ArchiveContribution {
  const _OtherVersion();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'other.archive',
    implementationVersion: '1',
    contractVersion: '0',
    formatVersion: 'x',
    capabilityId: 'archive.FR',
  );
}

void main() {
  test('every installed add-on declares the current contract and one country', () {
    final ids = <String>{};
    for (final c in installedArchives) {
      final d = c.descriptor;
      expect(d.contractVersion, archiveContractVersion, reason: d.moduleId);
      expect(d.capabilityId, startsWith('archive.'));
      expect(ids.add(d.capabilityId), isTrue, reason: 'one add-on per country');
    }
    expect(ids, {
      'archive.CA',
      'archive.CH',
      'archive.DE',
      'archive.FR',
      'archive.GB',
      'archive.IE',
      'archive.US',
    });
  });

  test('the FEC and the procedures belong to France and Switzerland alone', () {
    expect(archiveOf('FR')!.archiveMembers, {'fec'});
    expect(archiveOf('fr')!.archiveMembers, {'fec'});
    expect(archiveOf('CH')!.archiveMembers, {'procedures'});
    for (final c in ['DE', 'IT', 'ES', 'GB', 'CA', '', 'ZZ']) {
      expect(archiveOf(c)?.archiveMembers ?? const <String>{}, isEmpty, reason: c);
    }
  });

  test('the readable handover is the English-speaking countries\'', () {
    for (final c in ['GB', 'IE', 'CA', 'US', 'ie']) {
      expect(archiveOf(c)!.readableHandover, isTrue, reason: c);
    }
    for (final c in ['DE', 'FR', 'CH', 'ES', 'IT']) {
      expect(archiveOf(c)?.readableHandover ?? false, isFalse, reason: c);
    }
  });

  test('a country with no add-on asks nothing, and never another\'s', () {
    for (final c in ['AT', 'PL', '', '  ', 'XX']) {
      expect(
        resolveArchive(LegalContext(countryCode: c), installedArchives),
        isNull,
        reason: c,
      );
    }
  });

  test('two add-ons for one country, or a wrong contract version, are errors', () {
    expect(
      () => resolveArchive(
        const LegalContext(countryCode: 'FR'),
        const [FrArchive(), FrArchive()],
      ),
      throwsStateError,
    );
    expect(
      () => resolveArchive(
        const LegalContext(countryCode: 'FR'),
        const [_OtherVersion()],
      ),
      throwsStateError,
    );
  });
}
