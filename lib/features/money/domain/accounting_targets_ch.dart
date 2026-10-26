// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Swiss targets: the booking journal of a local book and its Banana
// layout, bexio through its API, and the other products a Swiss fiduciary
// runs, catalogued with how far each is qualified. Where a product's own
// import is not specified yet, the Swiss journal is the working route.
import 'accounting_format.dart';

/// The booking journal of a Swiss local book: its postings on the KMU
/// chart, the MWST code and the Ziffer of the MWST-Abrechnung per row, the
/// QR reference of each receivable. An exchange file a person reviews.
const _swissJournalFormat = AccountingFormat(
  id: 'ch_kmu',
  claim: FormatClaim.exchange,
  extension: 'csv',
  needsAccounts: true,
);

/// The same rows under Banana Accounting+'s column names, for its import
/// of transactions (a tab-separated text file).
const _bananaFormat = AccountingFormat(
  id: 'banana_transactions',
  claim: FormatClaim.exchange,
  extension: 'txt',
  needsAccounts: true,
);

const _journalOperations = {
  AccountingOperation.sale,
  AccountingOperation.credit,
  AccountingOperation.receipt,
  AccountingOperation.refund,
  AccountingOperation.writeOff,
  AccountingOperation.expense,
};

/// The Swiss targets, in the order the sheet lists them.
const List<AccountingTarget> swissAccountingTargets = [
  AccountingTarget(
    id: 'ch_kmu',
    vendor: 'KMU-Kontenrahmen',
    product: 'Swiss booking journal',
    edition: 'CSV from compute_postings, MWST code and Ziffer per row',
    countries: {'CH'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _journalOperations,
    taxCodeModel: TaxCodeModel.perRate,
    format: _swissJournalFormat,
  ),
  AccountingTarget(
    id: 'banana_transactions',
    vendor: 'Banana',
    product: 'Banana Accounting+',
    edition: 'import of transactions, tab-separated text',
    countries: {'CH'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _journalOperations,
    taxCodeModel: TaxCodeModel.perRate,
    format: _bananaFormat,
  ),
  // bexio takes the documents through its API: an invoice created with its
  // legal number and issued, positions net with the tax id the connection
  // maps, payments on the invoice. The adapter is
  // supabase/functions/_shared/accounting_bexio.ts; a company connects with a
  // personal access token or by signing in to the installation's app.
  AccountingTarget(
    id: 'bexio_api',
    vendor: 'bexio',
    product: 'bexio',
    edition: 'API 2.0 (kb_invoice, kb_credit_voucher)',
    countries: {'CH'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
    },
    taxCodeModel: TaxCodeModel.perRate,
    connectsBy: {AccountingAuthKind.token, AccountingAuthKind.oauth2},
  ),
  // Licensed or unpublished interfaces: catalogued, not reachable until a
  // specification (and for Abacus a licence) is in hand.
  AccountingTarget(
    id: 'abacus_abaconnect',
    vendor: 'Abacus',
    product: 'Abacus Finanzbuchhaltung',
    edition: 'AbaConnect XML, licensed per interface',
    countries: {'CH'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _journalOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'sage50_extra_ch',
    vendor: 'Sage',
    product: 'Sage 50 Extra / Sage Start (CH)',
    edition: 'text import of Buchungen',
    countries: {'CH'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _journalOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'infoniqa_one',
    vendor: 'Infoniqa',
    product: 'Infoniqa ONE',
    edition: 'API',
    countries: {'CH'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'klara',
    vendor: 'Klara',
    product: 'Klara Business',
    edition: 'API',
    countries: {'CH'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'run_my_accounts',
    vendor: 'Run my Accounts',
    product: 'Run my Accounts',
    edition: 'API',
    countries: {'CH'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
  ),
];
