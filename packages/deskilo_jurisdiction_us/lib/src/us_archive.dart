// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the American yearly archive carries the readable handover.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const usArchiveImplementationVersion = '1';

/// The American archive.
class UsArchive extends ArchiveContribution {
  const UsArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'us.archive',
    implementationVersion: usArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'readable-handover',
    capabilityId: 'archive.US',
  );

  @override
  bool get readableHandover => true;

  @override
  bool get retentionExtendsBySetting => true;
}
