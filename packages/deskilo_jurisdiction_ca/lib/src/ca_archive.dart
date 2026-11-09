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

  /// ETA s.286 and ITA s.230: the records are kept in Canada unless the CRA
  /// permits otherwise.
  @override
  RecordsNotice? recordsNotice(RecordsFacts facts) {
    if (facts.hostingCountry == 'CA') return null;
    final reference = facts.authorisationReference;
    return RecordsNotice(
      id: 'cra',
      readmeLines: [
        if (facts.hostingCountry == null)
          'Nothing declares these records kept in Canada (ETA s.286, '
              'ITA s.230).'
        else
          'These records are kept outside Canada (ETA s.286, ITA s.230).',
        if (reference.isEmpty)
          'CRA authorisation reference: none recorded.'
        else
          'CRA authorisation reference: $reference.',
      ],
    );
  }
}
