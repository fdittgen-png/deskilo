// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3333 -- a filing file as the product writes it: the installed add-on of the
// party's country, through the contract, with the form boxes filled from the
// installed tax reference. The writers left `vat_filing_files.dart`; tests of
// what they write read the file from here.
import 'dart:convert';

import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/filing_context_builder.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';

/// The file of [declaration] for [party]; throws [VatFilingFileException] with
/// the stable problem when the add-on refuses it, [UnsupportedError] when no
/// add-on is installed for the country.
({String fileName, String text}) productFile(
  VatDeclaration declaration,
  VatFilingParty party, {
  VatFilingFacts facts = const VatFilingFacts(),
  DateTime? now,
}) {
  final resolution = resolveCapability(
    JurisdictionOperation.vatFiling,
    LegalContext(countryCode: party.countryCode),
    installedVatFilings,
  );
  if (resolution is! Resolved) {
    throw UnsupportedError('no filing file for ${party.countryCode}');
  }
  final contribution = resolution.contribution;
  final checked = contribution.validate(
    filingContextOf(
      declaration: declaration,
      party: party,
      now: now ?? DateTime.utc(2026, 10, 2, 12),
      facts: facts, reference: ActiveTaxReference.current,
      extraForms: contribution.extraForms),
  );
  final filing = checked.filing;
  if (filing == null) {
    throw VatFilingFileException(
      VatFilingFileProblem.values.byName(checked.result.codes.first),
    );
  }
  final artifact = contribution.build(filing);
  // the Spanish 303 is ISO-8859-1, every other file UTF-8
  final text = artifact.mediaType.contains('iso-8859-1')
      ? latin1.decode(artifact.bytes)
      : utf8.decode(artifact.bytes);
  return (fileName: artifact.fileName, text: text);
}
