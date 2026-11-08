// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the French yearly archive carries the FEC (the regulatory accounting file, art. L47 A LPF).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const frArchiveImplementationVersion = '1';

/// The French archive.
class FrArchive extends ArchiveContribution {
  const FrArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fr.archive',
    implementationVersion: frArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'art-l102-b-lpf',
    capabilityId: 'archive.FR',
  );

  @override
  Set<String> get archiveMembers => const {'fec'};
}
