// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- the host's side of the contract: the filing context built from the
// application's own types (a declaration, the party, the facts), with the form
// boxes filled from the installed tax reference. Every country add-on lives in
// its own package; this is the one place the application's types are turned
// into the contract's.

import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

import '../../../../core/jurisdiction/jurisdiction_resolver.dart';
import '../../domain/vat_filing_files.dart';

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
  required TaxReferenceSet reference,

  /// The forms the add-on of the party's country files beside the main one
  /// (`VatFilingContribution.extraForms`): the host fills their boxes.
  Set<String> extraForms = const {},
}) => FilingContext(
  extraBoxes: {
    for (final form in extraForms)
      form: [
        for (final b
            in vatExtraFormBoxes(form, declaration.lines, reference: reference) ??
                (throw StateError('no host fill for the form $form')))
          _boxOf(b),
      ],
  },
  boxes: [
    for (final b in vatFormBoxes(
      LegalContext(countryCode: party.countryCode).normalized,
      declaration.lines,
      periodEnd: declaration.periodEnd,
      reference: reference,
    ))
      _boxOf(b),
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

FilingBox _boxOf(VatFormBox b) => FilingBox(
  code: b.code,
  label: b.label,
  netCents: b.netCents,
  vatCents: b.vatCents,
  hasBase: b.hasBase,
  hasTax: b.hasTax,
  baseKey: b.baseKey,
  taxKey: b.taxKey,
);
