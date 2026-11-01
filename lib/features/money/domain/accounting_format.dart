// SPDX-License-Identifier: AGPL-3.0-or-later

/// The accounting exports the app offers, and — the part that matters —
/// **what each one claims about itself** (#669).
///
/// These files are legally consequential. A wrong one is worse than
/// none: it is a false statement to a tax authority, and it gets unbound
/// by hand. So every format here carries its [claim] explicitly, and the
/// export sheet shows it. Three kinds, and the difference is not
/// cosmetic:
///
///  * [FormatClaim.regulatory] — this file is what a named authority
///    asks for, produced to their published spec and to the SCOPE that
///    spec defines for a system like this one. The FEC is one. So is a
///    SAF-T(PT) declared as invoicing-only, because Portugal defines
///    that variant precisely for systems that keep no ledger.
///  * [FormatClaim.exchange] — an accountant's software reads it and a
///    PERSON reviews and posts what it contains. DATEV and Sage are
///    these. No authority is being told anything, which is exactly why
///    they can be produced honestly without a chart of accounts.
///  * [FormatClaim.subset] — the shape is real but the file is
///    deliberately partial, and it says so in its own header. The
///    generic SAF-T is this: the OECD tree with `GeneralLedgerEntries`
///    omitted on purpose.
///
/// The ACCOUNTING variants of SAF-T mandate `GeneralLedgerEntries` over a
/// chart of accounts. #2379 writes them from a local book's postings
/// (`accounting_targets_saft.dart`): Norway's and Luxembourg's FAIA, and
/// the OECD tree. Portugal's `TaxAccountingBasis` 'C' stays absent (it
/// needs certified software), and Poland's JPK_KR, Romania's D406,
/// Lithuania's and Austria's each wait for their own profile. #2373 — Sage's German lines (KHK / Office Line)
/// import DATEV and the French ones the FEC (`accounting_targets_sage.dart`).
library;

import 'package:meta/meta.dart';

import 'accountant_csv.dart';
import 'accounting_target.dart';
import 'accounting_targets_business_central.dart';
import 'accounting_targets_ch.dart';
import 'accounting_targets_de.dart';
import 'accounting_targets_hmrc.dart';
import 'accounting_targets_quickbooks.dart';
import 'accounting_targets_saft.dart';
import 'accounting_targets_sage.dart';
import 'accounting_targets_xero.dart';

export 'accounting_target.dart';

/// What a produced file claims about itself. Never widen one of these
/// without the authority's own spec in hand.
enum FormatClaim { regulatory, exchange, subset }

/// One offerable export.
class AccountingFormat {
  const AccountingFormat({
    required this.id,
    required this.claim,
    required this.extension,
    this.needsAccounts = false,
    this.needsLegalId = false,
    this.uncertifiedSoftware = false,
  });

  /// Stable wire id — also the l10n key suffix and the test anchor.
  final String id;

  final FormatClaim claim;

  final String extension;

  /// The format posts to a chart of accounts DesKilo does not own, so
  /// the export must ASK for the numbers and show them before writing.
  /// Never invent them: every wrong code is unbooked by hand.
  final bool needsAccounts;

  /// The file is named after, or must carry, the company's registration
  /// number — refusing early beats producing a file the authority will
  /// reject on its name alone.
  final bool needsLegalId;

  /// The jurisdiction operates a software CERTIFICATION scheme and
  /// DesKilo is not certified under it.
  ///
  /// Portugal is the case that forced this field. Its spec is public and
  /// the file this app produces is true to it — but Portuguese
  /// taxpayers above the statutory threshold must use *certified*
  /// invoicing software, and a structurally perfect file from
  /// uncertified software does not satisfy that obligation. The file
  /// declares `SoftwareCertificateNumber` 0, which is the defined value
  /// for "not certified", and the export sheet says so out loud.
  ///
  /// Producing the file quietly and letting the owner assume it settles
  /// their obligation would be exactly the overclaim this whole registry
  /// exists to prevent.
  final bool uncertifiedSoftware;
}

/// SAF-T, invoicing subset — the OECD tree, ledger omitted on purpose.
@visibleForTesting
const safTFormat = AccountingFormat(
  id: 'saft',
  claim: FormatClaim.subset,
  extension: 'xml',
);

/// Portugal's SAF-T declared as `TaxAccountingBasis = 'F'` (faturação).
///
/// This one IS regulatory, and the reason is worth stating because it
/// looks like it should not be: Portugal defines the invoicing-only
/// variant *for systems that do not keep books*. Declaring 'F' is not a
/// partial 'C' — it is a different, complete declaration, and omitting
/// `GeneralLedgerEntries` is what 'F' requires rather than something it
/// tolerates.
@visibleForTesting
const safTPtFormat = AccountingFormat(
  id: 'saft_pt',
  claim: FormatClaim.regulatory,
  extension: 'xml',
  needsLegalId: true,
  // See the field's own comment: the SPEC is met, the CERTIFICATION
  // obligation is a separate one and this app does not meet it.
  uncertifiedSoftware: true,
);

/// France's flat file, the one an audit demands.
@visibleForTesting
const fecFormat = AccountingFormat(
  id: 'fec',
  claim: FormatClaim.regulatory,
  extension: 'txt',
  needsAccounts: true,
  needsLegalId: true,
);

/// DATEV EXTF Buchungsstapel — what a German or Austrian Steuerberater
/// imports. Switzerland is NOT here: DATEV is a German-market product
/// and a Swiss fiduciary does not run it.
///
/// The export is a zip: one Buchungsstapel per month and journal, the
/// Debitoren-Stammdaten, and the vouchers the rows link.
const _datevFormat = AccountingFormat(
  id: 'datev',
  claim: FormatClaim.exchange,
  extension: 'zip',
  needsAccounts: true,
);

/// Sage 50's audit-trail CSV — the British import shape.
const _sageFormat = AccountingFormat(
  id: 'sage50',
  claim: FormatClaim.exchange,
  extension: 'csv',
  needsAccounts: true,
);

/// A plain, self-describing CSV for every accountant with no national
/// mandate behind them — most of the 32 supported countries.
///
/// The count used to read "ten of the fourteen". The catalogue grew to
/// 32 with #534 and this sentence did not, which in a file whose whole
/// purpose is not overclaiming is the wrong sentence to leave stale.
/// `docs/domain/ACCOUNTING_EXPORTS.md` carries the country-by-country
/// map, including what each one mandates that this app does not
/// produce.
///
/// Offered EVERYWHERE rather than only where nothing is mandated: an
/// accountant in France may still prefer a readable file to an FEC, and
/// the format claims nothing that could mislead them.
const _accountantCsvFormat = AccountingFormat(
  id: 'accountant_csv',
  claim: FormatClaim.exchange,
  extension: 'csv',
);

/// #2370 / #2365 — the generic journal: the posting engine's entries, one
/// row per line, for any accounting system without a national format.
/// Offered everywhere; it claims to be an exchange file and nothing more.
const _genericJournalFormat = AccountingFormat(
  id: 'generic_journal_csv',
  claim: FormatClaim.exchange,
  extension: 'csv',
);

/// The complete audit TRAIL — every invoice, payment, credit note and
/// write-off with who did what and when.
///
/// Named a trail, never an "audit file", and the distinction is the
/// whole point: a national audit file is a regulated artefact with a
/// schema and a validator, and this is not one. It is the evidence
/// behind the numbers, which is what an accountant or an inspector
/// actually asks for first.
@visibleForTesting
const auditTrailFormat = AccountingFormat(
  id: 'audit_trail',
  claim: FormatClaim.exchange,
  extension: 'csv',
);

/// #957 — one download per fiscal year: every invoice as PDF/A-3 with its
/// embedded e-invoice, the register, the FEC and the audit trail. Not a
/// filing — an archive an auditor opens; offered everywhere.
@visibleForTesting
const archiveBundleFormat = AccountingFormat(
  id: 'bundle',
  claim: FormatClaim.exchange,
  extension: 'zip',
  needsLegalId: true,
);

/// #2358 — France's e-reporting: the B2C and international transactions
/// and the payment data of the month's last invoiced period, in the
/// structure of the DGFiP flows 10.1-10.4. The plateforme agréée maps it;
/// the file is never presented as the filing itself.
/// #2376 — the books as the accountant reads them, printed from the same
/// postings as the FEC: the general ledger, the trial balance (general and
/// auxiliary) and the journals with their summary. Report kinds of the
/// designer, written as PDF.
const _generalLedgerFormat = AccountingFormat(
  id: 'general_ledger',
  claim: FormatClaim.exchange,
  extension: 'pdf',
);

const _trialBalanceFormat = AccountingFormat(
  id: 'trial_balance',
  claim: FormatClaim.exchange,
  extension: 'pdf',
);

const _journalsFormat = AccountingFormat(
  id: 'journals',
  claim: FormatClaim.exchange,
  extension: 'pdf',
);

/// #2376 — the report formats printed from a local book's postings.
const Set<String> bookReportFormats = {
  'general_ledger',
  'trial_balance',
  'journals',
};

const _frEReportingFormat = AccountingFormat(
  id: 'fr_ereporting',
  claim: FormatClaim.subset,
  extension: 'xml',
);

/// What to offer in [countryCode], most specific first.
List<AccountingFormat> formatsFor(String countryCode) => [
  for (final t in targetsFor(countryCode))
    ?t.format,
];

/// #2370 — every target, in the order the sheet lists them: the country's
/// own regulatory file first when there is one, then exchange formats,
/// then the generic fallbacks. Someone under audit is looking for one
/// specific file and should not have to read past three alternatives to
/// find it.
const List<AccountingTarget> accountingTargets = [
  AccountingTarget(
    id: 'fec',
    vendor: 'DGFiP',
    authority: true,
    product: 'FEC',
    edition: 'BIC/IS, art. A47 A-1 LPF',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
    format: fecFormat,
    // #2376 — the client code of an auxiliary account: the plan
    // comptable's practice of up to 13 capitals and digits after the
    // collective's root (411DUPONT01).
    customerIdRule: CustomerIdRule(maxLength: 13, charset: r'[A-Z0-9]+'),
  ),
  AccountingTarget(
    id: 'fr_ereporting',
    vendor: 'DGFiP',
    authority: true,
    product: 'e-reporting',
    edition: 'flows 10.1-10.4',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt},
    taxCodeModel: TaxCodeModel.perRate,
    format: _frEReportingFormat,
  ),
  AccountingTarget(
    id: 'saft_pt',
    vendor: 'Autoridade Tributária',
    authority: true,
    product: 'SAF-T (PT)',
    edition: '1.04_01, TaxAccountingBasis F',
    countries: {'PT'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
    format: safTPtFormat,
  ),
  AccountingTarget(
    id: 'datev',
    vendor: 'DATEV',
    product: 'Rechnungswesen',
    edition: 'EXTF 700 Buchungsstapel',
    countries: {'DE', 'AT'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.perRate,
    format: _datevFormat,
  ),
  ...germanAccountingTargets,
  AccountingTarget(
    id: 'sage50',
    vendor: 'Sage',
    product: 'Sage 50 Accounts',
    edition: 'audit trail CSV',
    // #2373 — the `sage/*` rows are the UK product's code table; Ireland
    // waits for its own rows.
    countries: {'GB'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff},
    taxCodeModel: TaxCodeModel.perRate,
    format: _sageFormat,
    customerIdRule: CustomerIdRule(maxLength: 8, charset: r'[A-Z0-9]+'),
  ),
  ...swissAccountingTargets,
  ...safTFinancialTargets,
  ...hmrcAccountingTargets,
  AccountingTarget(
    id: 'saft',
    vendor: 'OECD',
    authority: true,
    product: 'SAF-T',
    edition: '2.0, ledger omitted',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit},
    taxCodeModel: TaxCodeModel.perRate,
    format: safTFormat,
  ),
  AccountingTarget(
    id: 'accountant_csv',
    vendor: deskiloVendor,
    product: 'Accountant CSV',
    edition: 'format $accountantCsvFormatVersion',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund},
    // #2378 — every tax component in its own column.
    taxCodeModel: TaxCodeModel.perComponent,
    format: _accountantCsvFormat,
  ),
  AccountingTarget(
    id: 'generic_journal_csv',
    vendor: deskiloVendor,
    product: 'Generic journal CSV',
    edition: 'compute_postings',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.perRate,
    format: _genericJournalFormat,
  ),
  AccountingTarget(
    id: 'general_ledger',
    vendor: deskiloVendor,
    product: 'General ledger',
    edition: 'PDF from compute_postings',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
    format: _generalLedgerFormat,
  ),
  AccountingTarget(
    id: 'trial_balance',
    vendor: deskiloVendor,
    product: 'Trial balance',
    edition: 'general and auxiliary, PDF from compute_postings',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
    format: _trialBalanceFormat,
  ),
  AccountingTarget(
    id: 'journals',
    vendor: deskiloVendor,
    product: 'Journals',
    edition: 'per journal and summary, PDF from compute_postings',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
    format: _journalsFormat,
  ),
  AccountingTarget(
    id: 'audit_trail',
    vendor: deskiloVendor,
    product: 'Audit trail',
    edition: 'CSV',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff},
    taxCodeModel: TaxCodeModel.none,
    format: auditTrailFormat,
  ),
  AccountingTarget(
    id: 'bundle',
    vendor: deskiloVendor,
    product: 'Fiscal-year archive',
    edition: 'PDF/A-3 bundle',
    countries: <String>{},
    transport: AccountingTransport.file,
    payload: AccountingPayload.documents,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.attachment},
    taxCodeModel: TaxCodeModel.none,
    format: archiveBundleFormat,
  ),
  // #2376 — the French platforms. Pennylane takes the postings through
  // its API, each one a balanced ledger entry in the journal of its code
  // (supabase/functions/_shared/accounting_pennylane.ts); importing the
  // invoices with their PDF/A-3 waits for the PDF on the server. Cegid Quadra and EBP
  // import the FEC today; their own import formats wait for a reviewed
  // specification.
  AccountingTarget(
    id: 'pennylane_api',
    runnerDelivers: true,
    vendor: 'Pennylane',
    product: 'Pennylane',
    edition: 'API v2',
    countries: {'FR'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff},
    taxCodeModel: TaxCodeModel.perRate,
    customerIdRule: CustomerIdRule(maxLength: 13, charset: r'[A-Z0-9]+'),
    // A company API token from Pennylane's settings, or a sign-in where
    // the installation registered a Pennylane partner application.
    connectsBy: {AccountingAuthKind.token, AccountingAuthKind.oauth2},
  ),
  AccountingTarget(
    id: 'cegid_quadra_ascii',
    vendor: 'Cegid',
    product: 'Quadra',
    edition: 'ASCII import',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
  ),
  AccountingTarget(
    id: 'ebp_import',
    vendor: 'EBP',
    product: 'Comptabilité',
    edition: 'import of entries',
    countries: {'FR'},
    transport: AccountingTransport.file,
    payload: AccountingPayload.journal,
    operations: {AccountingOperation.sale, AccountingOperation.credit, AccountingOperation.receipt, AccountingOperation.refund, AccountingOperation.writeOff, AccountingOperation.expense},
    taxCodeModel: TaxCodeModel.none,
  ),
  ...quickbooksAccountingTargets,
  ...sageAccountingTargets,
  ...xeroAccountingTargets,
  ...businessCentralAccountingTargets,
];

/// #2370 — the targets offered in [countryCode], in registry order.
List<AccountingTarget> targetsFor(String countryCode) => [
  for (final t in accountingTargets)
    if (t.offeredIn(countryCode)) t,
];

/// #2373 — the products offered in [countryCode] that import another
/// target's file, grouped by the id of that target, in registry order.
Map<String, List<AccountingTarget>> importRoutesFor(String countryCode) {
  final routes = <String, List<AccountingTarget>>{};
  for (final t in targetsFor(countryCode)) {
    if (t.importsTargetId case final via?) (routes[via] ??= []).add(t);
  }
  return routes;
}
