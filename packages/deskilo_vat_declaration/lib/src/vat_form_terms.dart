// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the terms the per-country VAT form files are written in: sales
// and input-VAT line selectors and the roundings a form uses.
import 'vat_declaration.dart';
import 'vat_forms.dart';

const vatTaxable = {'S'};
const vatAsset = {'asset'};

/// The acquisition tax owed on services bought from abroad (CH 383).
const vatAcquisition = {vatAcquisitionCategory};

VatTerm vatSales({
  Set<double>? rates,
  Set<String>? categories = vatTaxable,
  bool? correction,
  int vatSign = 0,
  int factor = 1,
  Set<String>? schemes,
}) => VatTerm.lines(
  VatLineSelector(
    rates: rates,
    categories: categories,
    correction: correction,
    vatSign: vatSign,
    schemes: schemes,
  ),
  factor: factor,
);

/// The part of the taxed sales that is an exempt letting the seller opted
/// to tax (CH 205): a base, no tax.
const vatOpted = VatTerm.lines(
  VatLineSelector(categories: vatTaxable, opted: true),
);

VatTerm vatInput({
  Set<String>? categories,
  bool? correction,
  int vatSign = 0,
  int factor = 1,
  Set<String>? schemes,
}) => VatTerm.lines(
  VatLineSelector(
    input: true,
    categories: categories,
    correction: correction,
    vatSign: vatSign,
    schemes: schemes,
  ),
  factor: factor,
);

const vatWhole = VatRounding.wholeHalfUp;

/// A cell a coworking space always files as zero (UK boxes 2, 8 and 9:
/// goods moved to or from the EU).
const vatNothing = VatTerm.lines(VatLineSelector(categories: <String>{}));

const vatWholeDown = VatRounding.wholeDown;
