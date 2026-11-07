// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3405 -- the package's VAT component arithmetic, with the installed snapshot passed in.
// Importers keep the old call shape; the package version takes the set.

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

/// The components of a combined [percent] (see the package); the installed
/// snapshot answers when no [reference] is given.
List<pkg.VatComponent> vatComponentsOf(
  String country,
  double percent,
  int netCents,
  int vatCents, {
  String? asOf,
  TaxReferenceSet? reference,
}) => pkg.vatComponentsOf(
  country,
  percent,
  netCents,
  vatCents,
  asOf: asOf,
  reference: reference ?? ActiveTaxReference.current,
);
