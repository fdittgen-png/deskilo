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
  AccountingExportContribution('fec', _namedWhenLocalBook),
  AccountingExportContribution('fr_ereporting', _documents),
  AccountingExportContribution('saft_pt', _documents),
  AccountingExportContribution('datev', _namedWhenLocalBook),
  AccountingExportContribution('gobd', _documents),
  AccountingExportContribution('sage50', _namedWhenLocalBook),
  AccountingExportContribution('ch_kmu', _postedOnlyNamed),
  AccountingExportContribution('banana_transactions', _postedOnlyNamed),
  AccountingExportContribution('saft_no', _postedOnlyWithOpening),
  AccountingExportContribution('faia_lu', _postedOnlyWithOpening),
  AccountingExportContribution('saft_ro', _postedOnlyWithOpening),
  AccountingExportContribution('saft_at', _postedOnlyWithOpening),
  AccountingExportContribution('saft_dk', _postedOnlyWithOpening),
  AccountingExportContribution('saft_oecd_full', _postedOnlyWithOpening),
  AccountingExportContribution('saft', _postedWhenLocalBook),
  AccountingExportContribution('accountant_csv', _documents),
  AccountingExportContribution(
    'generic_journal_csv',
    SourceRequirements(posting: ExportPosting.only),
  ),
  AccountingExportContribution('general_ledger', _namedWhenLocalBook),
  AccountingExportContribution('trial_balance', _namedWhenLocalBook),
  AccountingExportContribution('journals', _namedWhenLocalBook),
  AccountingExportContribution('audit_trail', _documents),
  AccountingExportContribution(
    'bundle',
    SourceRequirements(
      posting: ExportPosting.whenLocalBook,
      named: true,
      archive: true,
    ),
  ),
  AccountingExportContribution('xero_invoice_csv', _documents),
];

/// The requirements [formatId] declares; a format that declares none reads the
/// documents only.
SourceRequirements requirementsOf(String formatId) {
  for (final c in installedAccountingExports) {
    if (c.formatId == formatId) return c.requirements;
  }
  return const SourceRequirements();
}
