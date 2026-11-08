// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'lipe_writer.dart';

/// Bumped when what the add-on WRITES changes (a box, a schema version): the
/// application's parity goldens change in the same commit. 1 = the writer as it
/// stood when it left the application (#3333).
const String itImplementationVersion = '1';

/// The profile the file follows: the fornitura IVP18 of the Agenzia delle
/// Entrate.
const String itFormatVersion = 'lipe-ivp18';

/// The Italian VAT filing: the LIPE as the XML of the fornitura IVP18.
class ItVatFilingContribution extends VatFilingContribution {
  const ItVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'it.vat_filing',
    implementationVersion: itImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: itFormatVersion,
    capabilityId: 'vat_filing.IT',
  );

  @override
  String get fileButtonId => 'lipeXml';

  @override
  Set<String> get factsAsked => const {'italianDeclarant'};

  @override
  Set<String> get registers => const {'itRegistro'};

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
    try {
      lipeXml(context);
    } on LipeRefusal catch (e) {
      return (
        filing: null,
        result: ValidationResult.refused([ValidationIssue(e.code)]),
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
    if (context.party.countryCode.trim().toUpperCase() != 'IT' ||
        validate(context).filing == null) {
      throw StateError(
        'it.vat_filing was asked to build a filing it would not validate',
      );
    }
    return GeneratedArtifact(
      bytes: utf8.encode(lipeXml(context)),
      mediaType: 'application/xml',
      fileName: 'lipe-${ymd(context.periodStart, separator: '-')}.xml',
      provenance: descriptor.toProvenance(),
    );
  }
}
