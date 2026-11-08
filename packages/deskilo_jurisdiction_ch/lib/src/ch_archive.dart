// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Swiss yearly archive carries the documentation of the procedures the record-keeping ordinance asks for (GeBüV art. 4).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const chArchiveImplementationVersion = '1';

/// The Swiss archive.
class ChArchive extends ArchiveContribution {
  const ChArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ch.archive',
    implementationVersion: chArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'gebuev-art-4',
    capabilityId: 'archive.CH',
  );

  @override
  Set<String> get archiveMembers => const {'procedures'};
}
