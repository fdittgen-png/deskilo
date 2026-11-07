// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'elster_writer.dart';

/// Bumped when what the add-on WRITES changes (a Kennzahl, a layout year): the
/// application's parity goldens change in the same commit. 1 = the writer as
/// it stood when it left the application (#3333).
const String deImplementationVersion = '1';

/// The profile the file follows: ELSTER's UStVA transfer format, version 11.
const String deFormatVersion = 'elster-ustva-v11';

/// The German VAT filing: the UStVA as ELSTER XML.
class DeVatFilingContribution implements VatFilingContribution {
  const DeVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'de.vat_filing',
    implementationVersion: deImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: deFormatVersion,
    capabilityId: 'vat_filing.DE',
  );

  @override
  Set<FilingSource> get requiredSources => const {
    FilingSource.declaration,
    FilingSource.party,
    FilingSource.facts,
  };

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    // The period first, then the Steuernummer: the order the writer refused in.
    final issue = elsterPeriod(context) == null
        ? const ValidationIssue('period')
        : digitsOf(context.facts.taxNumber).length < 10
        ? const ValidationIssue('taxNumber', field: 'facts.taxNumber')
        : null;
    if (issue != null) {
      return (filing: null, result: ValidationResult.refused([issue]));
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
    if (context.party.countryCode.trim().toUpperCase() != 'DE' ||
        validate(context).filing == null) {
      throw StateError(
        'de.vat_filing was asked to build a filing it would not validate',
      );
    }
    final text = elsterUstvaXml(
      context,
      zeitraum: elsterPeriod(context)!,
      taxNumber: context.facts.taxNumber,
    );
    return GeneratedArtifact(
      bytes: utf8.encode(text),
      mediaType: 'application/xml',
      fileName: 'ustva-${ymd(context.periodStart, separator: '-')}.xml',
      provenance: descriptor.toProvenance(),
    );
  }
}
