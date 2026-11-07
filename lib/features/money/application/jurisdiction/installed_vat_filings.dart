// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- the VAT filing add-ons this build installs: a static
// list, compiled in (no downloadable plugin). One entry per country the
// dispatcher served before, with the same file names, encodings and bytes.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';

import '../../../../core/jurisdiction/jurisdiction_resolver.dart';
import 'legacy_vat_filing_contribution.dart';

/// Bumped when what an add-on WRITES changes (a rate, a box, a layout year):
/// the parity goldens change in the same commit. Starts at 1 for the writers
/// as they stood when they were put behind the contract.
const String _legacyImplementationVersion = '1';

CapabilityDescriptor _descriptor(String country, String formatVersion) =>
    CapabilityDescriptor(
      moduleId: '${country.toLowerCase()}.vat_filing',
      implementationVersion: _legacyImplementationVersion,
      contractVersion: jurisdictionContractVersion,
      formatVersion: formatVersion,
      capabilityId: vatFilingCapabilityId(country),
    );

/// Every installed VAT filing add-on. `formatVersion` names the profile the
/// writer follows: bumped when the authority's schema or layout year changes.
final List<VatFilingContribution> installedVatFilings = [
  LegacyVatFilingContribution(
    _descriptor('DE', 'elster-ustva-v11'),
    mediaType: 'application/xml',
  ),
  // #3332: the French add-on lives in its own package.
  const FrVatFilingContribution(),
  LegacyVatFilingContribution(
    _descriptor('GB', 'mtd-bridging-csv'),
    mediaType: 'text/csv',
  ),
  LegacyVatFilingContribution(
    _descriptor('CH', 'ech-0217-2'),
    mediaType: 'application/xml',
  ),
  LegacyVatFilingContribution(
    _descriptor('CA', 'gst34-fpz500-csv'),
    mediaType: 'text/csv',
  ),
  LegacyVatFilingContribution(
    _descriptor('ES', 'aeat-303-2026'),
    mediaType: 'text/plain',
  ),
  LegacyVatFilingContribution(
    _descriptor('IT', 'lipe-ivp18'),
    mediaType: 'application/xml',
  ),
];
