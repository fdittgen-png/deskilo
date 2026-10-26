// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail of one accounting export run: a local
// book's postings of the fiscal year (the run's one postings read) on the
// book's chart, or the year's documents on the nominal codes the person
// confirms. The tax codes come from the tax reference the workspace's
// context holds; nothing here reads the period again.
import '../../../core/vat/tax_reference_active.dart';
import '../application/generic_journal_export.dart';
import '../domain/sage.dart';
import '../domain/sage_documents.dart';
import '../domain/sage_postings.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart';
import 'posting_kind_labels.dart';
import 'widgets/export_accounts_dialogs.dart';

GenericJournal _written(SageAuditTrail trail) => trail.blockers.isEmpty
    ? JournalFile(sageFile(trail.rows))
    : JournalSageRefused(trail.blockers);

extension SageAccountingExports on AccountingExportRun {
  Future<void> sageExport() async {
    final reference = workspaceTaxReference(ref);
    final customers = SageCustomers(
      memberNumbers: await memberNumbers(),
      sellerCountry: country,
    );
    if (!context.mounted) return;
    final name = sageFileName(year, invoices.last.issuedAt.month);
    final journal = posted;
    if (journal != null) {
      // A local book's codes are its installation's; refused, never
      // guessed, while the workspace context is not ready.
      if (reference == null) throw StateError('workspace context not ready');
      final documents = {for (final i in exported) i.id: i};
      return exportGenericJournal(
        context,
        () async => journal is JournalPosted
            ? _written(
                sageRowsOfPostings(
                  journal.postings,
                  accounts: SageAccounts(reference: reference),
                  parties: journal.parties,
                  documents: documents,
                  customers: customers,
                  baseCurrency:
                      journal.functionalCurrency ?? workspace.currencyCode,
                  kindText: (kind) => postingKindLabel(l10n, kind),
                ),
              )
            : journal,
        save: (content) => save(content, name),
      );
    }
    final accounts = await showSageAccountsDialog(context);
    if (accounts == null || !context.mounted) return;
    final groups = reference ?? ActiveTaxReference.current;
    await exportGenericJournal(
      context,
      () async => _written(
        sageRowsOfInvoices(
          invoices: exported,
          matches: matches,
          accounts: accounts,
          customers: customers,
          baseCurrency: workspace.currencyCode,
          groupOf: (t) => groups.groupOfRate(country, t.percent, t.category),
        ),
      ),
      save: (content) => save(content, name),
    );
  }
}
