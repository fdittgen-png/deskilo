// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Xero, one target per region of its organisations (the region decides the
// tax rates an organisation holds): invoices and credit notes as their own
// documents with the legal number, credit notes allocated to the invoice
// they correct, payments against their invoice, every other event as a
// manual journal, through supabase/functions/_shared/accounting_xero.ts.
// Reached by signing in to a Xero application of the installation; the
// sign-in binds the one organisation it authorised.
import 'accounting_format.dart';

/// The operations every Xero region takes.
const Set<AccountingOperation> _xeroOperations = {
  AccountingOperation.sale,
  AccountingOperation.credit,
  AccountingOperation.receipt,
  AccountingOperation.refund,
  AccountingOperation.writeOff,
  AccountingOperation.expense,
};

/// The Xero targets, in the order the sheet lists them.
const List<AccountingTarget> xeroAccountingTargets = [
  AccountingTarget(
    id: 'xero_gb',
    runnerDelivers: true,
    vendor: 'Xero',
    product: 'Xero',
    edition: 'Accounting API 2.0, UK organisation',
    countries: {'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _xeroOperations,
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'xero_ca',
    runnerDelivers: true,
    vendor: 'Xero',
    product: 'Xero',
    edition: 'Accounting API 2.0, Canadian organisation',
    countries: {'CA'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _xeroOperations,
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'xero_us',
    runnerDelivers: true,
    vendor: 'Xero',
    product: 'Xero',
    edition: 'Accounting API 2.0, US organisation',
    countries: {'US'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _xeroOperations,
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'xero_eu',
    runnerDelivers: true,
    vendor: 'Xero',
    product: 'Xero',
    edition: 'Accounting API 2.0, EU organisation',
    countries: {accountingCountriesEu},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _xeroOperations,
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
];
