// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2361 -- the Canadian return as one CSV: `return, business_number,
// period_start, period_end, line, label, base, tax`, the GST34 lines then the
// FPZ-500 QST lines. Amounts in dollars and cents, a line-101 base in whole
// dollars as the form takes it. The quick-method flag is not a column: the
// remittance of that method is the CRA's own calculation. Moved here unchanged
// from the application (#3333).
import 'dart:convert';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart';

/// Bumped when what the add-on WRITES changes: the application's parity
/// goldens change in the same commit. 1 = the writer as it stood when it left
/// the application (#3333).
const String caImplementationVersion = '1';

/// The profile the file follows: the GST34 lines then the FPZ-500 lines.
const String caFormatVersion = 'gst34-fpz500-csv';

/// The name under which the host passes the Quebec form's boxes.
const String caQstFormName = 'FPZ-500';

/// The Canadian VAT filing: GST/HST and QST as one CSV.
class CaVatFilingContribution extends VatFilingContribution {
  const CaVatFilingContribution();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ca.vat_filing',
    implementationVersion: caImplementationVersion,
    contractVersion: jurisdictionContractVersion,
    formatVersion: caFormatVersion,
    capabilityId: 'vat_filing.CA',
  );

  @override
  Set<String> get extraForms => const {};

  @override
  Set<FilingSource> get requiredSources => const {
    FilingSource.declaration,
    FilingSource.party,
  };

  @override
  ({ValidatedFiling? filing, ValidationResult result}) validate(
    FilingContext context,
  ) {
    if (!isValidCanadianBn(context.party.vatId)) {
      return (
        filing: null,
        result: ValidationResult.refused(const [
          ValidationIssue('businessNumber', field: 'party.vatId'),
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
    if (context.party.countryCode.trim().toUpperCase() != 'CA' ||
        validate(context).filing == null) {
      throw StateError(
        'ca.vat_filing was asked to build a filing it would not validate',
      );
    }
    final bn = formatCanadianRegistration(context.party.vatId);
    final rows = <List<String>>[
      [
        'return',
        'business_number',
        'period_start',
        'period_end',
        'line',
        'label',
        'base',
        'tax',
      ],
    ];
    void section(String name, List<FilingBox> boxes) {
      for (final box in boxes) {
        rows.add([
          name,
          bn,
          ymd(context.periodStart, separator: '-'),
          ymd(context.periodEnd, separator: '-'),
          box.code,
          box.label,
          if (box.hasBase) _dollars(box.netCents) else '',
          if (box.hasTax) _dollars(box.vatCents) else '',
        ]);
      }
    }

    section('GST34', context.boxes);
    section('FPZ-500', context.extraBoxes[caQstFormName] ?? const []);
    final text = rows
        .map(
          (r) => [
            for (final (i, cell) in r.indexed)
              // base and tax are numbers: never quoted, never apostrophed
              if (i >= 6) cell else csvCell(cell),
          ].join(','),
        )
        .map((r) => '$r\r\n')
        .join();
    return GeneratedArtifact(
      bytes: utf8.encode(text),
      mediaType: 'text/csv',
      fileName:
          'gst-hst-qst-return-${ymd(context.periodStart, separator: '-')}.csv',
      provenance: descriptor.toProvenance(),
    );
  }
}

/// Dollars with cents and a dot: `-12.05`.
String _dollars(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${twoDigits(abs % 100)}';
}
