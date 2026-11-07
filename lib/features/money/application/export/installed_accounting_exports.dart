// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3334 (of #3328) -- the accounting export formats this build offers, each
// with the sources it declares. This list REPLACES the five format-id sets
// `AccountingExportSource` used to hold; a drift test requires it to name
// exactly the file formats of the targets registry (`accountingTargets`), so a
// format added in one place without the other fails the build.
import 'package:meta/meta.dart';

import 'accounting_export_contribution.dart';

const _documents = SourceRequirements();
const _postedWhenLocalBook = SourceRequirements(
  posting: ExportPosting.whenLocalBook,
);
const _namedWhenLocalBook = SourceRequirements(
  posting: ExportPosting.whenLocalBook,
  named: true,
);
const _postedOnlyNamed = SourceRequirements(
  posting: ExportPosting.only,
  named: true,
);
const _postedOnlyWithOpening = SourceRequirements(
  posting: ExportPosting.only,
  named: true,
  withOpening: true,
);

/// Every registered format, in the order the targets registry lists them.
/// The host reads it through [requirementsOf]; the drift test and (next) the
/// export run read the list itself.
@visibleForTesting
const List<AccountingExportContribution> installedAccountingExports = [
  AccountingExportContribution('fec', ExportKind.fec, _namedWhenLocalBook),
  AccountingExportContribution(
    'fr_ereporting',
    ExportKind.frEReporting,
    _documents,
  ),
  AccountingExportContribution('saft_pt', ExportKind.saftPortugal, _documents),
  AccountingExportContribution('datev', ExportKind.sage, _namedWhenLocalBook),
  AccountingExportContribution('gobd', ExportKind.gobd, _documents),
  AccountingExportContribution('sage50', ExportKind.datev, _namedWhenLocalBook),
  AccountingExportContribution('ch_kmu', ExportKind.swissKmu, _postedOnlyNamed),
  AccountingExportContribution(
    'banana_transactions',
    ExportKind.swissBanana,
    _postedOnlyNamed,
  ),
  AccountingExportContribution(
    'saft_no',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution(
    'faia_lu',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution(
    'saft_ro',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution(
    'saft_at',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution(
    'saft_dk',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution(
    'saft_oecd_full',
    ExportKind.saftFinancial,
    _postedOnlyWithOpening,
  ),
  AccountingExportContribution('saft', ExportKind.saft, _postedWhenLocalBook),
  AccountingExportContribution(
    'accountant_csv',
    ExportKind.accountantCsv,
    _documents,
  ),
  AccountingExportContribution(
    'generic_journal_csv',
    ExportKind.genericJournal,
    SourceRequirements(posting: ExportPosting.only),
  ),
  AccountingExportContribution(
    'general_ledger',
    ExportKind.bookReport,
    _namedWhenLocalBook,
  ),
  AccountingExportContribution(
    'trial_balance',
    ExportKind.bookReport,
    _namedWhenLocalBook,
  ),
  AccountingExportContribution(
    'journals',
    ExportKind.bookReport,
    _namedWhenLocalBook,
  ),
  AccountingExportContribution(
    'audit_trail',
    ExportKind.auditTrail,
    _documents,
  ),
  AccountingExportContribution(
    'bundle',
    ExportKind.archiveBundle,
    SourceRequirements(
      posting: ExportPosting.whenLocalBook,
      named: true,
      archive: true,
    ),
  ),
  AccountingExportContribution(
    'xero_invoice_csv',
    ExportKind.xeroInvoices,
    _documents,
  ),
];

/// The requirements [formatId] declares; a format that declares none reads the
/// documents only.
SourceRequirements requirementsOf(String formatId) {
  for (final c in installedAccountingExports) {
    if (c.formatId == formatId) return c.requirements;
  }
  return const SourceRequirements();
}

/// The contribution registered for [formatId], or null for an id the registry
/// does not know.
AccountingExportContribution? contributionOf(String formatId) {
  for (final c in installedAccountingExports) {
    if (c.formatId == formatId) return c;
  }
  return null;
}
