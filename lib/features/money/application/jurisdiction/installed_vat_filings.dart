// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- the VAT filing add-ons this build installs: a static
// list, compiled in (no downloadable plugin). One entry per country the
// dispatcher served before, with the same file names, encodings and bytes.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';

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
  // #3332: the French add-on lives in its own package.
  const FrVatFilingContribution(),
  // #3333: the German, British and Canadian add-ons likewise.
  const DeVatFilingContribution(),
  const GbVatFilingContribution(),
  const CaVatFilingContribution(),
  const EsVatFilingContribution(),
  const ItVatFilingContribution(),
  LegacyVatFilingContribution(
    _descriptor('CH', 'ech-0217-2'),
    mediaType: 'application/xml',
  ),
];
