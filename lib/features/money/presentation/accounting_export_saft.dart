// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the SAF-T Financial files of one accounting export run: the local
// book's postings read once with the year (and the book's postings before
// it, for the opening balances), the profile's chart map from the tax
// reference store, the parties' addresses from the documents and the
// supplier register, and the contact person asked at export.
import '../application/generic_journal_export.dart';
import '../domain/saf_t.dart';
import '../domain/saf_t_financial.dart';
import '../providers/supplier_providers.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'e_invoice_identity.dart' show workspaceIban;
import 'invoice_actions.dart';
import 'widgets/saft_contact_dialog.dart';

extension SafTFinancialExports on AccountingExportRun {
  Future<void> safTFinancialExport() async {
    final contact = await showSafTContactDialog(context);
    if (contact == null || !context.mounted) return;
    await exportGenericJournal(
      context,
      () async => switch (posted) {
        final JournalPosted books => _written(books, contact, await _parties(books)),
        final other? => other,
        null => const JournalNeedsLocalBook(),
      },
      save: (content) => save(content, named(format.id.replaceAll('_', ' '))),
    );
  }

  /// The parties of the posted documents, the opening period's included,
  /// with their addresses: a member's from the document itself (read by id,
  /// whatever calendar year it was issued in), a supplier's as registered.
  Future<Map<String, SafTParty>> _parties(JournalPosted books) async =>
      safTPartyDetails(
        parties: books.parties,
        invoices: await invoiceQueries.fetchInvoices(workspace.id),
        suppliers: await ref.read(suppliersProvider(workspace.id).future),
      );

  Future<GenericJournal> _written(
    JournalPosted books,
    SafTContact contact,
    Map<String, SafTParty> parties,
  ) async {
    final reference = workspaceTaxReference(ref);
    if (reference == null) throw StateError('workspace context not ready');
    final request = SafTFinancialRequest(
      profile: SafTFinancialProfile.ofFormat(format.id)!,
      period: books.year,
      postings: books.postings,
      opening: books.opening,
      accountNames: books.accountNames,
      accountTypes: books.accountTypes,
      parties: books.parties,
      partyDetails: parties,
      company: company,
      companyIban: workspaceIban(workspace),
      contact: contact,
      currency: books.functionalCurrency ?? workspace.currencyCode,
      softwareVersion: safTSoftwareVersion,
      createdAt: now,
      reference: reference,
    );
    return switch (buildSafTFinancial(request)) {
      SafTFinancialFile(:final xml) => JournalFile(xml),
      SafTFinancialRefused(:final gaps) => JournalSafTRefused(gaps),
    };
  }
}
