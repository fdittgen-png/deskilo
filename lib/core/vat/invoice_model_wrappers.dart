// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3402 -- the invoice model's old-path wrappers, in ONE file: the only code
// in the invoice model's neighbourhood that reads the installed snapshot
// (ActiveTaxReference) or the workspace clock (WorkspaceTime). The package
// (deskilo_invoice_model) takes the reference and the day-of function as
// required parameters; these keep the old signatures and pass the globals.
// The old paths (invoice.dart, vat_compliance.dart, ...) re-export this file.
//
// #3403 sweep: callers switch to WorkspaceContext, then THIS FILE goes -- not
// a plain shim delete.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart'
    hide frozenTaxPointBasis,
    isEuCountry,
    taxPointsOf,
    vatTaxPointLedger;
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' as model
    show euMemberStatesOf, frozenTaxPointBasis, isEuCountry, taxPointsOf, vatTaxPointLedger;
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:meta/meta.dart';

import '../time/workspace_time.dart';
import 'tax_reference_active.dart';

/// #2354 -- the member states, ONE set for the whole app (the rows of the
/// `eu_member` domain of the installed tax reference).
Set<String> get euMemberStates =>
    model.euMemberStatesOf(ActiveTaxReference.current);

bool isEuCountry(String code, {TaxReferenceSet? reference}) =>
    model.isEuCountry(code, reference: reference ?? ActiveTaxReference.current);

@visibleForTesting
List<VatTaxPointAmount> taxPointsOf(
  Invoice invoice,
  List<TaxPointPayment> payments, {
  required VatTaxPointBasis basis,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.taxPointsOf(
  invoice,
  payments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);

@visibleForTesting
VatTaxPointBasis frozenTaxPointBasis(Invoice invoice, VatTaxPointBasis basis) =>
    model.frozenTaxPointBasis(
      invoice,
      basis,
      reference: ActiveTaxReference.current,
    );

List<VatTaxPointAmount> vatTaxPointLedger(
  Iterable<Invoice> invoices, {
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  VatTaxPointBasis basis = VatTaxPointBasis.invoiceDate,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => model.vatTaxPointLedger(
  invoices,
  matches: matches,
  instalments: instalments,
  basis: basis,
  reference: ActiveTaxReference.current,
  dayOf: dayOf,
);
