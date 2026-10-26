// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2374 — Microsoft Dynamics 365 Business Central, one target per
// localisation Microsoft ships for the app's countries (each localisation
// brings its own VAT or sales-tax setup): invoices and credit memos as
// their own documents with the legal number as external document number,
// posted as a separate step; receipts as customer payments applied to the
// posted invoice; every other event as general journal lines, through
// supabase/functions/_shared/accounting_business_central.ts. Reached with
// the client credentials of the Microsoft Entra application the company's
// administrator registered; the connection names the company by its id.
import 'accounting_format.dart';

/// The operations every Business Central localisation takes.
const Set<AccountingOperation> _operations = {
  AccountingOperation.sale,
  AccountingOperation.credit,
  AccountingOperation.receipt,
  AccountingOperation.refund,
  AccountingOperation.writeOff,
  AccountingOperation.expense,
};

/// A customer `number` is a Code[20].
const _customerIds = CustomerIdRule(maxLength: 20);

/// An environment takes 600 API calls a minute.
const _limits = TargetLimits(requestsPerMinute: 600);

/// The Business Central targets, in the order the sheet lists them.
const List<AccountingTarget> businessCentralAccountingTargets = [
  AccountingTarget(
    id: 'business_central_de',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, German localisation',
    countries: {'DE'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
  AccountingTarget(
    id: 'business_central_fr',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, French localisation',
    countries: {'FR'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
  AccountingTarget(
    id: 'business_central_ch',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, Swiss localisation',
    countries: {'CH'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
  AccountingTarget(
    id: 'business_central_gb',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, UK localisation',
    countries: {'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
  AccountingTarget(
    id: 'business_central_us',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, US localisation',
    countries: {'US'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
  AccountingTarget(
    id: 'business_central_ca',
    runnerDelivers: true,
    vendor: 'Microsoft',
    product: 'Dynamics 365 Business Central',
    edition: 'API v2.0, Canadian localisation',
    countries: {'CA'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _operations,
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: _customerIds,
    limits: _limits,
    connectsBy: {AccountingAuthKind.token},
    tokenShape: AccountingTokenShape.entraClientCredentials,
  ),
];
