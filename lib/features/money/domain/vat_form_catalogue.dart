// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 -- the package's form catalogue, with the installed snapshot passed in.

import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart' as pkg;
import 'package:meta/meta.dart';

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

/// Every form the app fills, as the installed reference data words and
/// groups them today.
@visibleForTesting
List<pkg.VatFormSpec> get vatFormCatalogue =>
    pkg.vatFormCatalogueOn(ActiveTaxReference.current);

/// The form [country] files for [periodEnd] (see the package).
pkg.VatFormSpec? vatFormSpecFor(
  String country,
  DateTime periodEnd, {
  TaxReferenceSet? reference,
}) => pkg.vatFormSpecFor(
  country,
  periodEnd,
  reference: reference ?? ActiveTaxReference.current,
);

/// Whether the return [country] files on [on] has a box for the acquisition
/// tax on services bought from abroad (see the package).
bool vatFormTaxesAcquisitions(
  String country,
  DateTime on, {
  TaxReferenceSet? reference,
}) => pkg.vatFormTaxesAcquisitions(
  country,
  on,
  reference: reference ?? ActiveTaxReference.current,
);
