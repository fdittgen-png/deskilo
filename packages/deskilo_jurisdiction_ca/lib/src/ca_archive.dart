// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Canadian yearly archive carries the readable handover (readable electronic records, English or French).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const caArchiveImplementationVersion = '1';

/// The Canadian archive.
class CaArchive extends ArchiveContribution {
  const CaArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ca.archive',
    implementationVersion: caArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'readable-handover',
    capabilityId: 'archive.CA',
  );

  @override
  bool get readableHandover => true;
}
