// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50's audit trail of one accounting export run: a local
// book's postings of the fiscal year (the run's one postings read) on the
// book's chart, or the year's documents on the nominal codes the person
// confirms. The tax codes come from the tax reference the workspace's
// context holds; nothing here reads the period again.
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart' show TaxReferenceQueries;
import '../../../l10n/app_localizations.dart';
import '../application/generic_journal_export.dart';
import '../domain/accounting_format.dart';
import '../domain/sage.dart';
import '../domain/sage_documents.dart';
import '../domain/sage_postings.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart';
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
  /// The codes and rate groups of this workspace's own installation;
  /// refused, never guessed, while its context is not ready: called inside
  /// the guarded builder, which says so.
  TaxReferenceSet _reference() =>
      workspaceTaxReference(ref) ??
      (throw StateError('workspace context not ready'));

  Future<void> sageExport() async {
    final customers = SageCustomers(
      memberNumbers: await memberNumbers(),
      sellerCountry: country,
    );
    if (!context.mounted) return;
    final name = sageFileName(year, invoices.last.issuedAt.month);
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
                    accounts: SageAccounts(reference: _reference()),
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
      initial: SageAccounts(reference: workspaceTaxReference(ref)),
    );
    if (accounts == null || !context.mounted) return;
    await exportGenericJournal(
      context,
      () async {
        final reference = _reference();
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
