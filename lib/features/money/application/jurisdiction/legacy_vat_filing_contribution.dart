// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 (of #3328) -- the CURRENT VAT filing writers behind the jurisdiction
// contract, unchanged. The adapter converts the contract's immutable context
// to the types the writers read, calls `vatFilingFile`, and converts what comes
// back: a [VatFilingFileException] is a [ValidationResult] of its stable
// problem code, the text and encoding are the artifact's bytes. Nothing the
// writers write changes (the parity suite pins it); the writers move into their
// own packages in #3332.
import 'dart:convert' show Encoding;
import 'dart:typed_data';

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

import '../../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../domain/vat_components.dart';
import '../../domain/vat_declaration.dart';
import '../../domain/vat_filing_files.dart';

/// One country's current writer, as a contribution.
class LegacyVatFilingContribution implements VatFilingContribution {
  const LegacyVatFilingContribution(this.descriptor, {required this.mediaType});

  @override
  final CapabilityDescriptor descriptor;

  /// The media type of the file the writer produces.
  final String mediaType;

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
      _write(context);
    } on VatFilingFileException catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'VAT filing refused (${e.problem.name})\n$st',
      );
      return (
        filing: null,
        result: ValidationResult.refused([ValidationIssue(e.problem.name)]),
      );
    }
    return (
      filing: ValidatedFiling(context),
      result: const ValidationResult.ok(),
    );
  }

  @override
  GeneratedArtifact build(ValidatedFiling filing) {
    // Never trust the token: a filing made by hand, or for another country's
    // add-on, is checked again here.
    if (!_isOwnCountry(filing.context.party.countryCode) ||
        validate(filing.context).filing == null) {
      throw StateError(
        '${descriptor.moduleId} was asked to build a filing it would not '
        'validate',
      );
    }
    final file = _write(filing.context);
    return GeneratedArtifact(
      bytes: Uint8List.fromList(file.encoding.encode(file.text)),
      mediaType: mediaType,
      fileName: file.fileName,
      provenance: descriptor.toProvenance(),
    );
  }

  /// Whether [countryCode] (as the host spells it: `UK` is `GB`) is the
  /// country this add-on files for.
  bool _isOwnCountry(String countryCode) => descriptor.capabilityId.endsWith(
    '.${LegalContext(countryCode: countryCode).normalized}',
  );

  ({String fileName, String text, Encoding encoding}) _write(
    FilingContext context,
  ) => vatFilingFile(
    declaration: _declarationOf(context),
    party: partyOf(context.party),
    now: context.generatedAt,
    facts: _factsOf(context.facts),
  );
}

/// The declaration a writer reads, from the contract's context.
VatDeclaration _declarationOf(FilingContext c) => VatDeclaration(
  id: '',
  workspaceId: '',
  periodStart: c.periodStart,
  periodEnd: c.periodEnd,
  status: 'prepared',
  lines: [for (final l in c.lines) _lineOf(l)],
  totalNetCents: 0,
  totalVatCents: 0,
  currency: c.currency,
  invoiceCount: 0,
  createdAt: c.generatedAt,
  number: c.number,
);

VatDeclarationLine _lineOf(FilingLine l) => VatDeclarationLine(
  percent: l.percent,
  grossCents: l.grossCents,
  netCents: l.netCents,
  vatCents: l.vatCents,
  invoiceCount: l.invoiceCount,
  category: l.category,
  direction: l.direction,
  optedNetCents: l.optedNetCents,
  corrects: l.corrects,
  correctsStart: l.correctsStart,
  correctsEnd: l.correctsEnd,
  components: [
    for (final k in l.components)
      VatComponent(
        scheme: k.scheme,
        authority: k.authority,
        percent: k.percent,
        baseCents: k.baseCents,
        taxCents: k.taxCents,
        name: k.name,
        level: k.level,
      ),
  ],
);

/// The party a writer reads.
VatFilingParty partyOf(FilingParty p) => VatFilingParty(
  countryCode: p.countryCode,
  name: p.name,
  street: p.street,
  postalCode: p.postalCode,
  city: p.city,
  vatId: p.vatId,
  legalId: p.legalId,
  onReceipts: p.onReceipts,
);

/// The facts a writer reads.
VatFilingFacts _factsOf(FilingFacts f) => VatFilingFacts(
  taxNumber: f.taxNumber,
  declarantFiscalCode: f.declarantFiscalCode,
  declarantRole: f.declarantRole,
  monthlyRefund: f.monthlyRefund,
  immediateSupply: f.immediateSupply,
  cashCriterionRecipient: f.cashCriterionRecipient,
);

/// The contract's context from the application's types: the host's side of
/// the conversion.
///
/// The form boxes are filled HERE, from [reference] (the application's
/// installed tax reference by default), and travel in the context: an
/// extracted add-on reads them, never a global (#3332).
FilingContext filingContextOf({
  required VatDeclaration declaration,
  required VatFilingParty party,
  required DateTime now,
  required VatFilingFacts facts,
  TaxReferenceSet? reference,
}) => FilingContext(
  boxes: [
    for (final b in vatFormBoxes(
      LegalContext(countryCode: party.countryCode).normalized,
      declaration.lines,
      periodEnd: declaration.periodEnd,
      reference: reference,
    ))
      FilingBox(
        code: b.code,
        label: b.label,
        netCents: b.netCents,
        vatCents: b.vatCents,
        hasBase: b.hasBase,
        hasTax: b.hasTax,
        baseKey: b.baseKey,
        taxKey: b.taxKey,
      ),
  ],
  periodStart: declaration.periodStart,
  periodEnd: declaration.periodEnd,
  currency: declaration.currency,
  number: declaration.number,
  generatedAt: now,
  lines: [
    for (final l in declaration.lines)
      FilingLine(
        percent: l.percent,
        netCents: l.netCents,
        vatCents: l.vatCents,
        grossCents: l.grossCents,
        invoiceCount: l.invoiceCount,
        category: l.category,
        direction: l.direction,
        optedNetCents: l.optedNetCents,
        corrects: l.corrects,
        correctsStart: l.correctsStart,
        correctsEnd: l.correctsEnd,
        components: [
          for (final k in l.components)
            FilingComponent(
              scheme: k.scheme,
              authority: k.authority,
              percent: k.percent,
              baseCents: k.baseCents,
              taxCents: k.taxCents,
              name: k.name,
              level: k.level,
            ),
        ],
      ),
  ],
  party: FilingParty(
    countryCode: party.countryCode,
    name: party.name,
    street: party.street,
    postalCode: party.postalCode,
    city: party.city,
    vatId: party.vatId,
    legalId: party.legalId,
    onReceipts: party.onReceipts,
  ),
  facts: FilingFacts(
    taxNumber: facts.taxNumber,
    declarantFiscalCode: facts.declarantFiscalCode,
    declarantRole: facts.declarantRole,
    monthlyRefund: facts.monthlyRefund,
    immediateSupply: facts.immediateSupply,
    cashCriterionRecipient: facts.cashCriterionRecipient,
  ),
);
