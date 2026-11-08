// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- moved to deskilo_invoice_model; this path re-exports it (and the
// wrappers that keep the old signatures) until the sweep PR (#3403).
export 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide frozenTaxPointBasis,
    isEuCountry,
    taxPointsOf,
    vatTaxPointLedger;
export '../../../core/vat/invoice_model_wrappers.dart';
