// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'aeat303_writer.dart';

/// Bumped when what the add-on WRITES changes (a casilla, a design year): the
/// application's parity goldens change in the same commit. 1 = the writer as it
/// stood when it left the application (#3333).
const String esImplementationVersion = '1';

/// The profile the file follows: the AEAT's design of the Modelo 303 for the
/// 2026 exercise (DR303e26v101).
const String esFormatVersion = 'aeat-303-2026';

/// The Spanish VAT filing: the Modelo 303 in the AEAT's "diseño de registro",
/// ISO-8859-1 bytes, one per position (the Sede reads it so).
class EsVatFilingContribution extends VatFilingContribution {
  const EsVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'es.vat_filing',
    implementationVersion: esImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: esFormatVersion,
    capabilityId: 'vat_filing.ES',
  );

  @override
  String get fileButtonId => 'aeat303';

  @override
  Set<String> get factsAsked => const {};

  @override
  Set<String> get registers => const {'esLibro', 'esSii', 'es347'};

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
      aeat303File(context);
    } on Aeat303Refusal catch (e) {
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
    if (context.party.countryCode.trim().toUpperCase() != 'ES' ||
        validate(context).filing == null) {
      throw StateError(
        'es.vat_filing was asked to build a filing it would not validate',
      );
    }
    return GeneratedArtifact(
      bytes: latin1.encode(aeat303File(context)),
      mediaType: 'text/plain; charset=iso-8859-1',
      fileName: 'modelo-303-${ymd(context.periodStart, separator: '-')}.txt',
      provenance: descriptor.toProvenance(),
    );
  }
}
