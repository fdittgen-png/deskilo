// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 -- the package's declaration model; the boxes, the QST part and the XML export
// read the installed snapshot when no reference is given.

import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart' as pkg;

import '../../../core/vat/tax_reference_active.dart';

export 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart'
    hide
        vatComponentsOf,
        vatDeclarationXml,
        vatFormBoxes,
        vatFormCatalogueOn,
        vatFormSpecFor,
        vatFormTaxesAcquisitions,
        vatQstFormBoxes;

/// The country's form boxes for [lines] (see the package).
List<pkg.VatFormBox> vatFormBoxes(
  String countryCode,
  List<pkg.VatDeclarationLine> lines, {
  DateTime? periodEnd,
  TaxReferenceSet? reference,
}) => pkg.vatFormBoxes(
  countryCode,
  lines,
  periodEnd: periodEnd,
  reference: reference ?? ActiveTaxReference.current,
);

/// The QST part of Revenu Québec's FPZ-500 (see the package).
List<pkg.VatFormBox> vatQstFormBoxes(
  List<pkg.VatDeclarationLine> lines, {
  TaxReferenceSet? reference,
}) => pkg.vatQstFormBoxes(
  lines,
  reference: reference ?? ActiveTaxReference.current,
);

/// The machine-readable export (see the package).
String vatDeclarationXml({
  required pkg.VatDeclaration declaration,
  required String workspaceName,
  required String vatId,
  required String countryCode,
  TaxReferenceSet? reference,
}) => pkg.vatDeclarationXml(
  declaration: declaration,
  workspaceName: workspaceName,
  vatId: vatId,
  countryCode: countryCode,
  reference: reference ?? ActiveTaxReference.current,
);
