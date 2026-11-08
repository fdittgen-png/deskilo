// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Irish yearly archive carries the readable handover.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const ieArchiveImplementationVersion = '1';

/// The Irish archive.
class IeArchive extends ArchiveContribution {
  const IeArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ie.archive',
    implementationVersion: ieArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'readable-handover',
    capabilityId: 'archive.IE',
  );

  @override
  bool get readableHandover => false;
}
