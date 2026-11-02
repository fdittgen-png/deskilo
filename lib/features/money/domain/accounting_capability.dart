// SPDX-License-Identifier: AGPL-3.0-or-later

/// What DesKilo may say about an accounting export beyond its [FormatClaim]
/// (#1868, checkpoint A): how far it has been QUALIFIED, and which
/// obligations the file cannot satisfy by itself.
///
/// The axes are kept apart on purpose. A structurally valid file is a
/// software fact; a statutory duty (complete posted books, software
/// certification) or an authority's acceptance is a different one, and the
/// highest software state never implies them. `unknown/requires-review` is
/// an answer, not a gap: nothing here invents an absence of obligations.
library;

import 'package:meta/meta.dart';

import 'accounting_format.dart';

/// How far a format's production has been qualified. Ordered: a later
/// state needs the earlier ones, but none of them settles an [Obligation].
enum QualificationState {
  unsupported,
  specificationNeeded,
  implemented,
  locallyValidated,
  targetAccepted,
}

/// A duty the produced file cannot discharge by being well-formed.
enum Obligation {
  /// The format is the authority's file over COMPLETE posted books; DesKilo
  /// holds invoices and payments, not a double-entry ledger (ADR 0022).
  completePostedBooks,

  /// The jurisdiction certifies invoicing software and DesKilo is not
  /// certified under it.
  softwareCertification,

  /// Nobody has told us the target accepted a file from this app.
  targetAcceptance,
}

/// The reference the Xero adapter was written against.
const String _xeroSpecification =
    'Xero Accounting API 2.0: Invoices ACCREC, CreditNotes ACCRECCREDIT with Allocations, Payments, ManualJournals, TaxRates';

/// The reference the QuickBooks Online adapter was written against.
const String _quickbooksSpecification =
    'QuickBooks Online Accounting API v3, minorversion 70: Invoice, CreditMemo, Payment, JournalEntry';

/// #2373 — the reference the Sage Business Cloud Accounting adapter was
/// written against.
const String _sageAccountingSpecification =
    'Sage Accounting API v3.1: sales_invoices, sales_credit_notes, contact_payments, contact_allocations, journals';

/// #2374 — the reference the Business Central adapter was written against.
const String _businessCentralSpecification =
    'Business Central API v2.0: salesInvoices, salesCreditMemos with Microsoft.NAV.post, customerPayments, journalLines, taxGroups';

class AccountingCapability {
  const AccountingCapability({
    required this.formatId,
    required this.state,
    this.obligations = const {Obligation.targetAcceptance},
    this.specification = '',
  });

  final String formatId;
  final QualificationState state;

  /// Everything still open between "the file is well-formed" and "the duty
  /// is met". Never empty for a regulatory format.
  final Set<Obligation> obligations;

  /// The published specification the production was reviewed against, with
  /// its version. Empty means none was reviewed — never a guessed URL.
  final String specification;

  /// A file of this format may be presented as the entity's complete
  /// statutory books only when nothing is outstanding.
  bool get mayPresentAsComplete => obligations.isEmpty;

  /// The export may be produced at all.
  bool get producible =>
      state.index >= QualificationState.implemented.index;
}

/// The reviewed decision for every offered format. Keyed by the format id so
/// a target added to [accountingTargets] without a decision is caught by the
/// qualification test rather than defaulting to "fine".
@visibleForTesting
const Map<String, AccountingCapability> accountingCapabilities = {
  // Reconstructed from invoices and payments. Without complete posted-book
  // evidence it is a reconstruction an accountant completes, not the entity's
  // FEC.
  'fec': AccountingCapability(
    formatId: 'fec',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'DGFiP fichiers standards des écritures comptables',
  ),
  // Invoicing-only declaration ('F'); the spec is met, certification is not.
  'saft_pt': AccountingCapability(
    formatId: 'saft_pt',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.softwareCertification,
      Obligation.targetAcceptance,
    },
    specification: 'SAF-T PT, TaxAccountingBasis F',
  ),
  'saft': AccountingCapability(
    formatId: 'saft',
    state: QualificationState.implemented,
    // The subset claim already says so in the file's own header and on the
    // row; no further obligation is asserted for a document handoff.
    obligations: {},
    specification: 'OECD SAF-T, ledger omitted on purpose',
  ),
  // #2379 — read against the authority's published schema in CI, and
  // refused while the chart map is incomplete. The postings are the local
  // book's, not necessarily the entity's complete books, and no authority
  // has received one yet.
  'saft_no': AccountingCapability(
    formatId: 'saft_no',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification:
        'Skatteetaten SAF-T Financial 1.30, Norwegian_SAF-T_Financial_Schema_v_1.30.xsd',
  ),
  'saft_dk': AccountingCapability(
    formatId: 'saft_dk',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification:
        'Erhvervsstyrelsen SAF-T Financial 2.1, Danish_SAF-T_Financial_Schema_v_2_1.xsd',
  ),
  'saft_ro': AccountingCapability(
    formatId: 'saft_ro',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'ANAF SAF-T D406, Ro_SAFT_Schema_v249_2025.xsd',
  ),
  'faia_lu': AccountingCapability(
    formatId: 'faia_lu',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'AED FAIA 2.01, FAIA_v_2.01_full.xsd',
  ),
  // The OECD publishes its 2.0 schema only inside its guidance; the file
  // is read against Luxembourg's publication of the same tree.
  'saft_oecd_full': AccountingCapability(
    formatId: 'saft_oecd_full',
    state: QualificationState.implemented,
    obligations: {},
    specification:
        'OECD SAF-T 2.0 guidance (2010), read against FAIA_v_2.01_full.xsd',
  ),
  // Denmark: a registered system is the main route; the SAF-T DK file
  // (#2379, above) is its standard export, and the systems wait for their
  // API agreements.
  'denmark_registered_system': AccountingCapability(
    formatId: 'denmark_registered_system',
    state: QualificationState.specificationNeeded,
  ),
  'economic_api': AccountingCapability(
    formatId: 'economic_api',
    state: QualificationState.specificationNeeded,
  ),
  'dinero_api': AccountingCapability(
    formatId: 'dinero_api',
    state: QualificationState.specificationNeeded,
  ),
  'billy_api': AccountingCapability(
    formatId: 'billy_api',
    state: QualificationState.specificationNeeded,
  ),
  'datev': AccountingCapability(
    formatId: 'datev',
    state: QualificationState.locallyValidated,
  ),
  // The Beschreibungsstandard and its DTD are the spec; the package holds
  // the sub-ledger, not complete books, and no auditor has read one yet.
  'gobd': AccountingCapability(
    formatId: 'gobd',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'GDPdU Beschreibungsstandard 1.1, gdpdu-01-08-2002.dtd',
  ),
  // Each needs a DATEV marketplace partnership and the client's SmartLogin.
  'datev_buchungsdatenservice': AccountingCapability(
    formatId: 'datev_buchungsdatenservice',
    state: QualificationState.specificationNeeded,
  ),
  'datev_rechnungsdatenservice': AccountingCapability(
    formatId: 'datev_rechnungsdatenservice',
    state: QualificationState.specificationNeeded,
  ),
  'datev_belegbilderservice': AccountingCapability(
    formatId: 'datev_belegbilderservice',
    state: QualificationState.specificationNeeded,
  ),
  'sage50': AccountingCapability(
    formatId: 'sage50',
    state: QualificationState.implemented,
  ),
  'ch_kmu': AccountingCapability(
    formatId: 'ch_kmu',
    state: QualificationState.implemented,
  ),
  // #2377 — the Swiss journal's rows under Banana's column names; the MWST
  // codes must exist in the Banana file's VAT table. No Banana import of a
  // file from this app has been reported yet.
  'banana_transactions': AccountingCapability(
    formatId: 'banana_transactions',
    state: QualificationState.implemented,
    specification: 'Banana Accounting+ import of transactions, column names of the Transactions table',
  ),
  // #2377 — the adapter maps the documents and delivers them once, read
  // back by document number; no live exchange has happened (no bexio test
  // company or registered app yet).
  'bexio_api': AccountingCapability(
    formatId: 'bexio_api',
    state: QualificationState.implemented,
    specification: 'bexio API 2.0, kb_invoice and kb_credit_voucher',
  ),
  // The Swiss journal is their working route; their own interfaces need a
  // specification (Abacus a licence per interface).
  'abacus_abaconnect': AccountingCapability(
    formatId: 'abacus_abaconnect',
    state: QualificationState.specificationNeeded,
  ),
  'sage50_extra_ch': AccountingCapability(
    formatId: 'sage50_extra_ch',
    state: QualificationState.specificationNeeded,
  ),
  'infoniqa_one': AccountingCapability(
    formatId: 'infoniqa_one',
    state: QualificationState.specificationNeeded,
  ),
  'klara': AccountingCapability(
    formatId: 'klara',
    state: QualificationState.specificationNeeded,
  ),
  'run_my_accounts': AccountingCapability(
    formatId: 'run_my_accounts',
    state: QualificationState.specificationNeeded,
  ),
  'accountant_csv': AccountingCapability(
    formatId: 'accountant_csv',
    state: QualificationState.implemented,
    obligations: {},
    // #2370 — DesKilo defines this file; its definition is the spec.
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  'generic_journal_csv': AccountingCapability(
    formatId: 'generic_journal_csv',
    state: QualificationState.implemented,
    obligations: {},
    // #2370 — DesKilo defines this file; its definition is the spec.
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  'audit_trail': AccountingCapability(
    formatId: 'audit_trail',
    state: QualificationState.implemented,
    obligations: {},
    // #2370 — DesKilo defines this file; its definition is the spec.
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  // The flows' structure; a plateforme agréée maps it, and the live
  // round-trip waits on a sandbox.
  'fr_ereporting': AccountingCapability(
    formatId: 'fr_ereporting',
    state: QualificationState.implemented,
    specification: 'DGFiP e-reporting flows 10.1-10.4 (structure only)',
  ),
  'bundle': AccountingCapability(
    formatId: 'bundle',
    state: QualificationState.implemented,
    obligations: {},
    // #2370 — DesKilo defines this file; its definition is the spec.
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  // #2376 — the books printed from the postings; DesKilo defines them.
  'general_ledger': AccountingCapability(
    formatId: 'general_ledger',
    state: QualificationState.implemented,
    obligations: {},
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  'trial_balance': AccountingCapability(
    formatId: 'trial_balance',
    state: QualificationState.implemented,
    obligations: {},
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  'journals': AccountingCapability(
    formatId: 'journals',
    state: QualificationState.implemented,
    obligations: {},
    specification: 'DesKilo-defined, docs/domain/ACCOUNTING_EXPORTS.md',
  ),
  // #2376 — the adapter delivers each posting once as a ledger entry, read
  // back by its external reference; no live exchange has happened (no
  // sandbox account yet).
  // #2470 — played from HMRC's public specification; no registered application and no sandbox submission yet.
  'hmrc_mtd': AccountingCapability(formatId: 'hmrc_mtd', state: QualificationState.implemented, specification: 'HMRC VAT (MTD) API 1.0, obligations and returns'),
  'pennylane_api': AccountingCapability(
    formatId: 'pennylane_api',
    state: QualificationState.implemented,
    specification: 'Pennylane API v2, ledger_entries and journals',
  ),
  // #2371 — delivered through the kit against a played realm; no sandbox
  // company has answered yet.
  'quickbooks_online_us': AccountingCapability(
    formatId: 'quickbooks_online_us',
    state: QualificationState.implemented,
    specification: _quickbooksSpecification,
  ),
  'quickbooks_online_ca': AccountingCapability(
    formatId: 'quickbooks_online_ca',
    state: QualificationState.implemented,
    specification: _quickbooksSpecification,
  ),
  'quickbooks_online_gb': AccountingCapability(
    formatId: 'quickbooks_online_gb',
    state: QualificationState.implemented,
    specification: _quickbooksSpecification,
  ),
  // #2372 — delivered through the kit against a played organisation; no
  // demo organisation has answered yet.
  'xero_gb': AccountingCapability(
    formatId: 'xero_gb',
    state: QualificationState.implemented,
    specification: _xeroSpecification,
  ),
  'xero_ca': AccountingCapability(
    formatId: 'xero_ca',
    state: QualificationState.implemented,
    specification: _xeroSpecification,
  ),
  'xero_us': AccountingCapability(
    formatId: 'xero_us',
    state: QualificationState.implemented,
    specification: _xeroSpecification,
  ),
  'xero_eu': AccountingCapability(
    formatId: 'xero_eu',
    state: QualificationState.implemented,
    specification: _xeroSpecification,
  ),
  // #2373 — delivered through the kit against a played business; no trial
  // business has answered yet.
  'sage_business_cloud_gb': AccountingCapability(
    formatId: 'sage_business_cloud_gb',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_ie': AccountingCapability(
    formatId: 'sage_business_cloud_ie',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_ca': AccountingCapability(
    formatId: 'sage_business_cloud_ca',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_us': AccountingCapability(
    formatId: 'sage_business_cloud_us',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_fr': AccountingCapability(
    formatId: 'sage_business_cloud_fr',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_de': AccountingCapability(
    formatId: 'sage_business_cloud_de',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  'sage_business_cloud_es': AccountingCapability(
    formatId: 'sage_business_cloud_es',
    state: QualificationState.implemented,
    specification: _sageAccountingSpecification,
  ),
  // #2374 — delivered through the kit against a played company; no
  // sandbox environment has answered yet.
  'business_central_de': AccountingCapability(
    formatId: 'business_central_de',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  'business_central_fr': AccountingCapability(
    formatId: 'business_central_fr',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  'business_central_ch': AccountingCapability(
    formatId: 'business_central_ch',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  'business_central_gb': AccountingCapability(
    formatId: 'business_central_gb',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  'business_central_us': AccountingCapability(
    formatId: 'business_central_us',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  'business_central_ca': AccountingCapability(
    formatId: 'business_central_ca',
    state: QualificationState.implemented,
    specification: _businessCentralSpecification,
  ),
  // #2373 — they import another target's file; that target's production
  // is theirs, and no import from them has been reported yet.
  'sage100_fr': AccountingCapability(
    formatId: 'sage100_fr',
    state: QualificationState.implemented,
    // The FEC's own: a reconstruction an accountant completes.
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'imports the FEC (target fec): DGFiP fichiers standards des écritures comptables',
  ),
  'sage50_fr': AccountingCapability(
    formatId: 'sage50_fr',
    state: QualificationState.implemented,
    // The FEC's own: a reconstruction an accountant completes.
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'imports the FEC (target fec): DGFiP fichiers standards des écritures comptables',
  ),
  'sage_de': AccountingCapability(
    formatId: 'sage_de',
    state: QualificationState.implemented,
    specification: 'imports DATEV (target datev): EXTF 700 Buchungsstapel',
  ),
  // The .IMP layout is in Sage's knowledge base only; Sage 200 and Intacct
  // are separate products with their own imports.
  'sage50_ca': AccountingCapability(
    formatId: 'sage50_ca',
    state: QualificationState.specificationNeeded,
  ),
  'sage200': AccountingCapability(
    formatId: 'sage200',
    state: QualificationState.specificationNeeded,
  ),
  'sage_intacct': AccountingCapability(
    formatId: 'sage_intacct',
    state: QualificationState.specificationNeeded,
  ),
  // The FEC is their working route today; their own formats need a spec.
  'cegid_quadra_ascii': AccountingCapability(
    formatId: 'cegid_quadra_ascii',
    state: QualificationState.specificationNeeded,
  ),
  'ebp_import': AccountingCapability(
    formatId: 'ebp_import',
    state: QualificationState.specificationNeeded,
  ),
};

/// The decision for [format]; a format nobody reviewed is `unsupported`
/// and blocked, never silently allowed.
AccountingCapability capabilityOf(AccountingFormat format) =>
    capabilityOfTarget(format.id);

/// The decision for the target [id] (a format id, or an API target's).
AccountingCapability capabilityOfTarget(String id) =>
    accountingCapabilities[id] ??
    AccountingCapability(formatId: id, state: QualificationState.unsupported);
