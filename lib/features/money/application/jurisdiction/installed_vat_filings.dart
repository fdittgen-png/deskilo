// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- the VAT filing add-ons this build installs: a static
// list, compiled in (no downloadable plugin). One entry per country the
// dispatcher served before, with the same file names, encodings and bytes.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_ca/deskilo_jurisdiction_ca.dart';
import 'package:deskilo_jurisdiction_ch/deskilo_jurisdiction_ch.dart';
import 'package:deskilo_jurisdiction_de/deskilo_jurisdiction_de.dart';
import 'package:deskilo_jurisdiction_es/deskilo_jurisdiction_es.dart';
import 'package:deskilo_jurisdiction_fr/deskilo_jurisdiction_fr.dart';
import 'package:deskilo_jurisdiction_gb/deskilo_jurisdiction_gb.dart';
import 'package:deskilo_jurisdiction_it/deskilo_jurisdiction_it.dart';

import '../../../../core/jurisdiction/jurisdiction_resolver.dart';


/// Every installed VAT filing add-on. `formatVersion` names the profile the
/// writer follows: bumped when the authority's schema or layout year changes.
final List<VatFilingContribution> installedVatFilings = [
  const FrVatFilingContribution(),
  const DeVatFilingContribution(),
  const GbVatFilingContribution(),
  const ChVatFilingContribution(),
  const CaVatFilingContribution(),
  const EsVatFilingContribution(),
  const ItVatFilingContribution(),
];

/// The installed VAT filing add-on of [country], or null where there is none:
/// what the screens ask about a country's filing, its identity fields and its
/// tax point (the add-on says, the screen never compares a code).
VatFilingContribution? vatFilingOf(String? country) {
  final resolution = resolveCapability(
    JurisdictionOperation.vatFiling,
    LegalContext(countryCode: country),
    installedVatFilings,
  );
  return resolution is Resolved ? resolution.contribution : null;
}

/// #3429 -- the country whose e-reporting flows the host exports: the one
/// installed VAT filing that asks for them. From the add-on, never a literal;
/// none or several is a programming error.
String get eReportingCountry => installedVatFilings
    .where((f) => f.eReporting)
    .map((f) => f.descriptor.country)
    .single;
