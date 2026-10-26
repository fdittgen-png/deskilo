// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the SAF-T Financial targets: the general ledger of a local book
// as the OECD tree, restricted per country (saf_t_financial.dart), and
// Denmark's routes, where the duty is a registered bookkeeping system
// rather than a file.
import 'accounting_format.dart';

/// Skatteetaten's SAF-T Financial 1.30. Regulatory: written to the
/// published schema it is read against in CI, and refused while an account
/// or a tax code has no standard code of Norway's code lists.
const _saftNoFormat = AccountingFormat(
  id: 'saft_no',
  claim: FormatClaim.regulatory,
  extension: 'xml',
  needsLegalId: true,
);

/// Luxembourg's FAIA 2.01, refused while an account has no standard
/// account or a party no postal address.
const _faiaLuFormat = AccountingFormat(
  id: 'faia_lu',
  claim: FormatClaim.regulatory,
  extension: 'xml',
  needsLegalId: true,
);

/// The OECD 2.0 tree with the ledger, no national restriction: what an
/// auditor's or an accountant's software reads anywhere.
const _saftOecdFullFormat = AccountingFormat(
  id: 'saft_oecd_full',
  claim: FormatClaim.exchange,
  extension: 'xml',
  needsLegalId: true,
);

const _ledgerOperations = {
  AccountingOperation.sale,
  AccountingOperation.credit,
  AccountingOperation.receipt,
  AccountingOperation.refund,
  AccountingOperation.writeOff,
  AccountingOperation.expense,
};

/// The SAF-T Financial targets, the national ones first.
const List<AccountingTarget> safTFinancialTargets = [
  AccountingTarget(
    id: 'saft_no',
    vendor: 'Skatteetaten',
    product: 'SAF-T Financial',
    edition: '1.30',
    countries: {'NO'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
    format: _saftNoFormat,
  ),
  AccountingTarget(
    id: 'faia_lu',
    vendor: "Administration de l'enregistrement",
    product: 'FAIA',
    edition: '2.01',
    countries: {'LU'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
    format: _faiaLuFormat,
  ),
  // Denmark (Bogføringsloven 2022): the duty is to keep the books in a
  // registered digital bookkeeping system; DesKilo is not one. The two
  // lawful routes are delivering to a registered system and the
  // Erhvervsstyrelsen's SAF-T DK standard export. Decided, not reachable.
  AccountingTarget(
    id: 'denmark_registered_system',
    vendor: 'Erhvervsstyrelsen',
    product: 'Registered digital bookkeeping system',
    edition: 'Bogføringsloven 2022',
    countries: {'DK'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'saft_dk',
    vendor: 'Erhvervsstyrelsen',
    product: 'SAF-T DK',
    edition: 'standard export with the standard chart mapping',
    countries: {'DK'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  // The registered systems a Danish space delivers to: candidates, each
  // waiting for its API agreement.
  AccountingTarget(
    id: 'economic_api',
    vendor: 'Visma',
    product: 'e-conomic',
    edition: 'REST API',
    countries: {'DK'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'dinero_api',
    vendor: 'Visma',
    product: 'Dinero',
    edition: 'API',
    countries: {'DK'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'billy_api',
    vendor: 'Billy',
    product: 'Billy',
    edition: 'API v2',
    countries: {'DK'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
  ),
  AccountingTarget(
    id: 'saft_oecd_full',
    vendor: 'OECD',
    product: 'SAF-T',
    edition: '2.0, general ledger from the posting engine',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: _ledgerOperations,
    taxCodeModel: TaxCodeModel.perRate,
    format: _saftOecdFullFormat,
  ),
];

/// #2379 — whether the law of [country] asks for a registered bookkeeping
/// system rather than a file (Denmark): the export sheet says so first.
bool needsRegisteredSystem(String country) => safTFinancialTargets.any(
  (t) => t.id == 'denmark_registered_system' && t.offeredIn(country),
);
