// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the British yearly archive carries the readable handover (no national audit file; readable electronic records in English).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const gbArchiveImplementationVersion = '1';

/// The British archive.
class GbArchive extends ArchiveContribution {
  const GbArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'gb.archive',
    implementationVersion: gbArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'readable-handover',
    capabilityId: 'archive.GB',
  );

  @override
  bool get readableHandover => true;
}
