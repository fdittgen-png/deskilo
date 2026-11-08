// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- a country that exists only in a test: the sixth-country proof of the
// jurisdiction contract. It is a plain implementation of the contract, written
// in the test tree, that writes a one-line text from its context; it is
// registered in a TEST composition (the `installed` list a test passes), never
// in `installedVatFilings`.
import 'dart:convert';

import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// A VAT filing add-on for [country] that writes one text line (the word FAKE,
/// the country, the period start, the number of lines and the tax number);
/// refuses a filing without a tax number as `taxNumber`.
class FakeVatFilingContribution extends VatFilingContribution {
  const FakeVatFilingContribution(
    this.country, {
    this.contractVersion = jurisdictionContractVersion,
  });

  final String country;
  final String contractVersion;

  @override
  CapabilityDescriptor get descriptor => CapabilityDescriptor(
    moduleId: 'fake.${country.toLowerCase()}.vat_filing',
    implementationVersion: '1',
    contractVersion: contractVersion,
    formatVersion: 'fake-text',
    capabilityId: vatFilingCapabilityId(country),
  );

  @override
  Set<FilingSource> get requiredSources => const {FilingSource.declaration};

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    if (context.facts.taxNumber.trim().isEmpty) {
      return (
        filing: null,
        result: ValidationResult.refused(const [
          ValidationIssue('taxNumber', field: 'facts.taxNumber'),
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
    final c = filing.context;
    if (validate(c).filing == null) throw StateError('refused');
    return GeneratedArtifact(
      bytes: utf8.encode(
        'FAKE $country ${c.periodStart.toIso8601String().substring(0, 10)} '
        '${c.lines.length} ${c.facts.taxNumber}\n',
      ),
      mediaType: 'text/plain',
      fileName: 'fake-${country.toLowerCase()}.txt',
      provenance: descriptor.toProvenance(),
    );
  }
}
