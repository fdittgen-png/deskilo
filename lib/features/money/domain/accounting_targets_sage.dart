// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — "Sage" is a family of unrelated products with unrelated imports,
// so each product edition is its own target:
//
//   * Sage 50 Accounts UK/IE writes its own audit trail (`sage50`, in the
//     registry beside DATEV);
//   * Sage Business Cloud Accounting, one target per region of its
//     businesses, delivered as documents through
//     supabase/functions/_shared/accounting_sage.ts, reached by signing in to
//     a Sage application of the installation;
//   * Sage 100 and Sage 50 in France import the FEC, Sage 50 and Sage 100 in
//     Germany and Austria import DATEV: they point to that target and write
//     nothing of their own;
//   * Sage 50 Canada's .IMP import, Sage 200 and Sage Intacct wait for a
//     reviewed specification and say so.
import 'accounting_format.dart';

/// The operations every Sage target takes, by API or by file.
const Set<AccountingOperation> _operations = {
  AccountingOperation.sale,
  AccountingOperation.credit,
  AccountingOperation.receipt,
  AccountingOperation.refund,
  AccountingOperation.writeOff,
  AccountingOperation.expense,
};


/// A Sage Business Cloud contact reference holds at most eight characters
/// (accounting_sage.ts `CONTACT_REFERENCE_LENGTH`).
const _contactReference = CustomerIdRule(maxLength: 8);

/// The Sage targets, in the order the sheet lists them.
const List<AccountingTarget> sageAccountingTargets = [
  AccountingTarget(
    id: 'sage_business_cloud_gb',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, UK business',
    countries: {'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_ie',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, Irish business',
    countries: {'IE'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_ca',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, Canadian business',
    countries: {'CA'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_us',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, US business',
    countries: {'US'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_fr',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, French business',
    countries: {'FR'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_de',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, German business',
    countries: {'DE'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage_business_cloud_es',
    runnerDelivers: true,
    vendor: 'Sage',
    product: 'Sage Business Cloud Accounting',
    edition: 'API v3.1, Spanish business',
    countries: {'ES'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _contactReference,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'sage100_fr',
    vendor: 'Sage',
    product: 'Sage 100 Comptabilité',
    edition: 'import of the FEC',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _operations,
    taxCodeModel: TaxCodeModel.none,
    importsTargetId: 'fec',
  ),
  AccountingTarget(
    id: 'sage50_fr',
    vendor: 'Sage',
    product: 'Sage 50 (ex Ciel Compta)',
    edition: 'import of the FEC',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _operations,
    taxCodeModel: TaxCodeModel.none,
    importsTargetId: 'fec',
  ),
  AccountingTarget(
    id: 'sage_de',
    vendor: 'Sage',
    product: 'Sage 50 / Sage 100 (KHK, Office Line)',
    edition: 'import of a DATEV EXTF Buchungsstapel',
    countries: {'DE', 'AT'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    importsTargetId: 'datev',
  ),
  // The tagged .IMP sales-invoice import and the general-journal .txt: the
  // field order and the version line are in Sage's own knowledge base, not
  // a public specification; the descriptor waits for it.
  AccountingTarget(
    id: 'sage50_ca',
    vendor: 'Sage',
    product: 'Sage 50 Accounting (Canada)',
    edition: '.IMP sales invoices and general journal',
    countries: {'CA'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.writeOff,
    },
    taxCodeModel: TaxCodeModel.perComponent,
  ),
  AccountingTarget(
    id: 'sage200',
    vendor: 'Sage',
    product: 'Sage 200',
    edition: 'import of transactions',
    countries: {'GB', 'IE'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'sage_intacct',
    vendor: 'Sage',
    product: 'Sage Intacct',
    edition: 'journal import templates and XML API',
    countries: {'US', 'CA', 'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.journal,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perComponent,
  ),
];
