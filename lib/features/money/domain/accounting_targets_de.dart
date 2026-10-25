// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The German targets beside DATEV's file export: the GoBD data handover an
// auditor reads, and DATEV's online services, decided and not reachable.
import 'accounting_format.dart';

/// The GoBD data handover (Z3) of a fiscal year: the Beschreibungsstandard's
/// index.xml with its DTD, one CSV per table, the vouchers and the
/// Verfahrensdokumentation. A subset: DesKilo's sub-ledger, not the
/// company's complete books, and its index says so.
const _gobdFormat = AccountingFormat(
  id: 'gobd',
  claim: FormatClaim.subset,
  extension: 'zip',
);

/// The German targets, in the order the sheet lists them after DATEV.
const List<AccountingTarget> germanAccountingTargets = [
  AccountingTarget(
    id: 'gobd',
    vendor: 'BMF',
    product: 'GoBD Datenträgerüberlassung (Z3)',
    edition: 'Beschreibungsstandard, gdpdu-01-08-2002.dtd',
    countries: {'DE'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.refund,
      AccountingOperation.writeOff,
      AccountingOperation.expense,
      AccountingOperation.attachment,
    },
    taxCodeModel: TaxCodeModel.none,
    format: _gobdFormat,
  ),
  // The DATEV online services take postings, invoices and voucher images
  // straight into the accountant's DATEV. Each needs a DATEV marketplace
  // partnership (DATEV-Marktplatz-Partner) and the client's own SmartLogin
  // authorisation; neither exists for DesKilo, so they are decided and not
  // reachable. The file export is the working route until then.
  AccountingTarget(
    id: 'datev_buchungsdatenservice',
    vendor: 'DATEV',
    product: 'Buchungsdatenservice',
    edition: 'DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin',
    countries: {'DE', 'AT'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.journal,
    operations: {
      AccountingOperation.sale,
      AccountingOperation.credit,
      AccountingOperation.receipt,
      AccountingOperation.refund,
      AccountingOperation.writeOff,
      AccountingOperation.expense,
    },
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'datev_rechnungsdatenservice',
    vendor: 'DATEV',
    product: 'Rechnungsdatenservice 1.0',
    edition: 'DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin',
    countries: {'DE', 'AT'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'datev_belegbilderservice',
    vendor: 'DATEV',
    product: 'Belegbilderservice',
    edition: 'DATEVconnect online, Marktplatz-Partnerschaft und SmartLogin',
    countries: {'DE', 'AT'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.attachment},
    taxCodeModel: TaxCodeModel.none,
  ),
];
