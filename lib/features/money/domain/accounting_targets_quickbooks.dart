// SPDX-License-Identifier: AGPL-3.0-or-later
//
// QuickBooks Online, one target per realm country (the realm's country
// decides its tax model): invoices, credit notes and payments as their own
// objects, every other event as a journal entry, through
// supabase/functions/_shared/accounting_quickbooks.ts. Reached by signing in
// to an Intuit application of the installation.
import 'accounting_format.dart';

/// The QuickBooks Online targets, in the order the sheet lists them.
const List<AccountingTarget> quickbooksAccountingTargets = [
  AccountingTarget(
    id: 'quickbooks_online_us',
    runnerDelivers: true,
    vendor: 'Intuit',
    product: 'QuickBooks Online',
    edition: 'Accounting API v3, US realm',
    countries: {'US'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.refund,
      AccountingOperation.writeOff,
      AccountingOperation.expense,
    },
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'quickbooks_online_ca',
    runnerDelivers: true,
    vendor: 'Intuit',
    product: 'QuickBooks Online',
    edition: 'Accounting API v3, CA realm',
    countries: {'CA'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.refund,
      AccountingOperation.writeOff,
      AccountingOperation.expense,
    },
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'quickbooks_online_gb',
    runnerDelivers: true,
    vendor: 'Intuit',
    product: 'QuickBooks Online',
    edition: 'Accounting API v3, GB realm',
    countries: {'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.refund,
      AccountingOperation.writeOff,
      AccountingOperation.expense,
    },
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
];
