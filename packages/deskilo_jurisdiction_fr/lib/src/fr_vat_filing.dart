// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'ca3_writer.dart';

/// Bumped when what the add-on WRITES changes (a code, a segment): the
/// application's parity goldens change in the same commit. 1 = the writer as
/// it stood when it left the application (#3332).
const String frImplementationVersion = '1';

/// The profile the file follows: the DGFiP's INFENT message of the CA3.
/// Bumped when the authority changes the message.
const String frFormatVersion = 'edi-tva-ca3-infent';

/// The French VAT filing: the CA3 as EDI-TVA.
class FrVatFilingContribution extends VatFilingContribution {
  const FrVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fr.vat_filing',
    implementationVersion: frImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: frFormatVersion,
    capabilityId: 'vat_filing.FR',
  );

  @override
  String get fileButtonId => 'ediTva';

  @override
  Set<FilingSource> get requiredSources => const {
    FilingSource.declaration,
    FilingSource.party,
  };

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    if (_siren(context).length < 9) {
      return (
        filing: null,
        result: ValidationResult.refused(const [
          ValidationIssue('taxNumber', field: 'party.legalId'),
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
    if (context.party.countryCode.trim().toUpperCase() != 'FR' ||
        validate(context).filing == null) {
      throw StateError(
        'fr.vat_filing was asked to build a filing it would '
        'not validate',
      );
    }
    final text = ediTvaCa3(context, siren: _siren(context));
    return GeneratedArtifact(
      bytes: utf8.encode(text),
      mediaType: 'application/edifact',
      fileName: 'edi-tva-ca3-${ymd(context.periodStart, separator: '-')}.edi',
      provenance: descriptor.toProvenance(),
    );
  }

  String _siren(FilingContext c) =>
      frenchSiren(legalId: c.party.legalId, vatId: c.party.vatId);
}
