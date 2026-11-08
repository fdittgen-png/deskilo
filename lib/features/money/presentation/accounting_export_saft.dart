// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the SAF-T Financial files of one accounting export run: the local
// book's postings read once with the year (and the book's postings before
// it, for the opening balances), the profile's chart map from the tax
// reference store, the parties' addresses from the documents and the
// supplier register, and the contact person asked at export.
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';

import '../../../core/vat/tax_reference.dart';
import '../application/generic_journal_export.dart';
import '../providers/supplier_providers.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'e_invoice_identity.dart' show workspaceIban;
import 'invoice_actions.dart';
import 'widgets/saft_contact_dialog.dart';
import 'widgets/saft_standard_accounts_dialog.dart';

extension SafTFinancialExports on AccountingExportRun {
  Future<void> safTFinancialExport() async {
    final profile = SafTFinancialProfile.ofFormat(format.id)!;
    final answers = await showSafTContactDialog(context, austria: profile.austriaShape);
    if (answers == null || !context.mounted) return;
    // #2379 — Austria: each book account's standard account, confirmed by
    // the person (the reference's role row is only the suggestion).
    var confirmed = const <String, AccountMapValue>{};
    // The parties are read once, for the suggestions and the file alike.
    Map<String, SafTParty>? read;
    if (posted case final JournalPosted books when profile.austriaShape) {
      final parties = read = await _parties(books);
      final suggestions = safTStandardSuggestions(_request(books, answers, parties));
      if (!context.mounted) return;
      final chosen = await showSafTStandardAccountsDialog(context, suggestions);
      if (chosen == null || !context.mounted) return;
      confirmed = chosen;
    }
    await exportGenericJournal(
      context,
      () async => switch (posted) {
        final JournalPosted books => _written(books, answers,
            format.id == 'jpk_kr_pl' ? const <String, SafTParty>{} : read ?? await _parties(books),
            confirmed),
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
    SafTHeaderAnswers answers,
    Map<String, SafTParty> parties,
    Map<String, AccountMapValue> confirmed,
  ) async =>
      switch (buildSafTFinancial(_request(books, answers, parties, confirmed))) {
        SafTFinancialFile(:final xml) => JournalFile(xml),
        SafTFinancialRefused(:final gaps) => JournalSafTRefused(gaps),
      };

  SafTFinancialRequest _request(
    JournalPosted books,
    SafTHeaderAnswers answers,
    Map<String, SafTParty> parties, [
    Map<String, AccountMapValue> confirmed = const {},
  ]) {
    final reference = workspaceTaxReference(ref);
    if (reference == null) throw StateError('workspace context not ready');
    return SafTFinancialRequest(
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
      contact: answers.contact,
      profitBasis: answers.profitBasis,
      industryCode: answers.industryCode,
      taxNumber: answers.taxNumber,
      smallBusiness: answers.smallBusiness,
      currency: books.functionalCurrency ?? workspace.currencyCode,
      softwareVersion: safTSoftwareVersion,
      createdAt: now,
      reference: reference,
      confirmedStandards: confirmed,
    );
  }
}
