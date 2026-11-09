// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

import 'mtd_boxes.dart';

/// Bumped when what the add-on WRITES changes: the application's parity
/// goldens change in the same commit. 1 = the writer as it stood when it left
/// the application (#3333).
const String gbImplementationVersion = '1';

/// The profile the file follows: HMRC's field names for MTD bridging.
const String gbFormatVersion = 'mtd-bridging-csv';

/// The British VAT filing: the nine boxes as one CSV row for MTD bridging
/// software (#2359). The row names the registration number's nine digits as
/// `vrn`.
class GbVatFilingContribution extends VatFilingContribution {
  const GbVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'gb.vat_filing',
    implementationVersion: gbImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: gbFormatVersion,
    capabilityId: 'vat_filing.GB',
  );

  @override
  String get fileButtonId => 'mtdCsv';

  @override
  bool get directSubmission => false;

  @override
  Set<String> get legalIdentityFields => const <String>{};

  @override
  Set<FilingSource> get requiredSources => const {
    FilingSource.declaration,
    FilingSource.party,
  };

  /// The nine digits of the registration number (`GB 123 4567 89`, `XI...`),
  /// or '' when there are fewer.
  String _vrn(FilingContext c) {
    final upper = c.party.vatId.toUpperCase().replaceAll(
      RegExp(r'[\s.\-]'),
      '',
    );
    final digits =
        (upper.startsWith('GB') || upper.startsWith('XI')
                ? upper.substring(2)
                : upper)
            .replaceAll(RegExp('[^0-9]'), '');
    return digits.length < 9 ? '' : digits.substring(0, 9);
  }

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    if (_vrn(context).isEmpty) {
      return (
        filing: null,
        result: ValidationResult.refused(const [
          ValidationIssue('vatNumber', field: 'party.vatId'),
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
    final country = context.party.countryCode.trim().toUpperCase();
    if ((country != 'GB' && country != 'UK') ||
        validate(context).filing == null) {
      throw StateError(
        'gb.vat_filing was asked to build a filing it would not validate',
      );
    }
    final cents = mtdBoxCentsOf(context.boxes);
    final header = ['vrn', 'periodStart', 'periodEnd', ...mtdBoxFields];
    final row = [
      _vrn(context),
      ymd(context.periodStart, separator: '-'),
      ymd(context.periodEnd, separator: '-'),
      for (final field in mtdBoxFields) mtdBoxText(field, cents[field]!),
    ];
    return GeneratedArtifact(
      bytes: utf8.encode('${header.join(',')}\r\n${row.join(',')}\r\n'),
      mediaType: 'text/csv',
      fileName:
          'mtd-vat-return-${ymd(context.periodStart, separator: '-')}.csv',
      provenance: descriptor.toProvenance(),
    );
  }
}
