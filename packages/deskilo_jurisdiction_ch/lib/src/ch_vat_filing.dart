// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'ech0217_writer.dart';

/// Bumped when what the add-on WRITES changes (an amount, a schema version): the
/// application's parity goldens change in the same commit. 1 = the writer as it
/// stood when it left the application (#3333).
const String chImplementationVersion = '1';

/// The profile the file follows: eCH-0217 version 2.0 (`VATDeclaration`),
/// validated against the published `eCH-0217-2-0-0.xsd`.
const String chFormatVersion = 'ech-0217-2';

/// The Swiss VAT filing: the MWST-Abrechnung as eCH-0217 XML.
class ChVatFilingContribution extends VatFilingContribution {
  const ChVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ch.vat_filing',
    implementationVersion: chImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: chFormatVersion,
    capabilityId: 'vat_filing.CH',
  );

  @override
  Set<FilingSource> get requiredSources => const {
    FilingSource.declaration,
    FilingSource.party,
  };

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    if (swissUidDigits(context.party.vatId) == null) {
      return (
        filing: null,
        result: ValidationResult.refused(const [
          ValidationIssue('uid', field: 'party.vatId'),
        ]),
      );
    }
    return (
      filing: ValidatedFiling(context),
      result: const ValidationResult.ok(),
    );
  }

  @override
  GeneratedArtifact build(ValidatedFiling filing) {
    final context = filing.context;
    // The token proves nothing: the checks are made again, and a filing of
    // another country is refused.
    if (context.party.countryCode.trim().toUpperCase() != 'CH' ||
        validate(context).filing == null) {
      throw StateError(
        'ch.vat_filing was asked to build a filing it would not validate',
      );
    }
    return GeneratedArtifact(
      bytes: utf8.encode(ech0217Xml(context)),
      mediaType: 'application/xml',
      fileName:
          'mwst-abrechnung-${ymd(context.periodStart, separator: '-')}.xml',
      provenance: descriptor.toProvenance(),
    );
  }
}
