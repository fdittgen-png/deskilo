// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the German yearly archive: a German business keeps its
// electronic books in Germany or another EU member state (§ 146 Abs. 2a AO),
// elsewhere only with the tax office's permission (Abs. 2b). Moved from the
// application with the README text unchanged.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this archive carries.
const deArchiveImplementationVersion = '1';

/// The German archive.
class DeArchive extends ArchiveContribution {
  const DeArchive();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'de.archive',
    implementationVersion: deArchiveImplementationVersion,
    contractVersion: archiveContractVersion,
    formatVersion: 'ao-146',
    capabilityId: 'archive.DE',
  );

  @override
  RecordsNotice? recordsNotice(RecordsFacts facts) {
    if (!facts.hostingInEu) return null;
    return RecordsNotice(
      id: 'ao',
      readmeLines: [
        if (facts.hostingCountry == null)
          'Nothing declares these books kept in Germany or another EU '
              'member state (§ 146 Abs. 2a AO).'
        else
          'These books are kept outside the EU: this needs the tax '
              "office's permission (§ 146 Abs. 2b AO).",
      ],
    );
  }
}
