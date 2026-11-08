// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail of one accounting export run: a local
// book's postings of the fiscal year (the run's one postings read) on the
// book's chart, or the year's documents on the nominal codes the person
// confirms. The tax codes come from the tax reference the workspace's
// context holds; nothing here reads the period again.
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import '../../../l10n/app_localizations.dart';
import '../application/generic_journal_export.dart';
import '../domain/accounting_format.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'posting_kind_labels.dart';
import 'widgets/accounting_export_sheet.dart';
import 'widgets/export_accounts_dialogs.dart';

/// #2373 — what the export sheet says of the products of [country] that
/// import one of its files (Sage 100 France the FEC, Sage 50 Germany
/// DATEV): the products and the file to choose.
List<String> importNotices(AppLocalizations l10n, String country) {
  final offered = {for (final f in formatsFor(country)) f.id};
  return [
    for (final MapEntry(key: via, value: products)
        in importRoutesFor(country).entries)
      if (offered.contains(via))
        l10n.exportImportedVia(
          products.map((t) => t.product).join(', '),
          products.length,
          accountingFormatName(l10n, via),
        ),
  ];
}

GenericJournal _written(SageAuditTrail trail) => trail.blockers.isEmpty
    ? JournalFile(sageFile(trail.rows))
    : JournalSageRefused(trail.blockers);

extension SageAccountingExports on AccountingExportRun {
  Future<void> sageExport() async {
    final customers = SageCustomers(
      memberNumbers: await memberNumbers(),
      sellerCountry: country,
    );
    if (!context.mounted) return;
    final name = sageFileName(year, invoices.last.issuedAt.month);
    // The workspace's reference was read once at the start of the run.
    final reference = taxReference;
    final journal = posted;
    if (journal != null) {
      final documents = {for (final i in exported) i.id: i};
      return exportGenericJournal(
        context,
        () async => journal is JournalPosted
            ? _written(
                sageRowsOfPostings(
                  journal.postings,
                  book: (
                    accounts: SageAccounts(reference: reference),
                    customers: customers,
                    baseCurrency:
                        journal.functionalCurrency ?? workspace.currencyCode,
                  ),
                  parties: journal.parties,
                  documents: documents,
                  kindText: (kind) => postingKindLabel(l10n, kind),
                ),
              )
            : journal,
        save: (content) => save(content, name),
      );
    }
    // The dialog proposes this workspace's own defaults when its context is
    // ready; the builder refuses the file otherwise.
    final accounts = await showSageAccountsDialog(
      context,
      initial: SageAccounts(reference: reference),
    );
    if (accounts == null || !context.mounted) return;
    await exportGenericJournal(
      context,
      () async {
        return _written(
          sageRowsOfInvoices(
            invoices: exported,
            matches: matches,
            accounts: accounts.on(reference),
            customers: customers,
            baseCurrency: workspace.currencyCode,
            groupOf: (t) =>
                reference.groupOfRate(country, t.percent, t.category),
          ),
        );
      },
      save: (content) => save(content, name),
    );
  }
}
