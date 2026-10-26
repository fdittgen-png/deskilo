// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — the SAF-T Financial files of one accounting export run: the local
// book's postings read once with the year (and the book's postings before
// it, for the opening balances), the profile's chart map from the tax
// reference store, the parties' addresses from the documents and the
// supplier register, and the person exporting as the file's contact.
import '../../profile/providers/profile_providers.dart';
import '../application/generic_journal_export.dart';
import '../domain/saf_t.dart';
import '../domain/saf_t_financial.dart';
import '../providers/supplier_providers.dart';
import 'accounting_export_journal.dart';
import 'accounting_export_run.dart';
import 'invoice_actions.dart';

extension SafTFinancialExports on AccountingExportRun {
  Future<void> safTFinancialExport() => exportGenericJournal(
    context,
    () async => switch (posted) {
      final JournalPosted books => _written(books, await _parties()),
      final other? => other,
      null => const JournalNeedsLocalBook(),
    },
    save: (content) => save(content, named(format.id.replaceAll('_', ' '))),
  );

  /// The address and tax number of every party the year's documents name:
  /// a member as the documents froze them, a supplier as registered.
  Future<Map<String, SafTParty>> _parties() async {
    final suppliers = await ref.read(suppliersProvider(workspace.id).future);
    return {
      for (final i in exported)
        if (i.buyerParty case final buyer? when buyer.memberNumber.isNotEmpty)
          safTPartyKey('member', buyer.memberNumber): SafTParty(
            name: buyer.name,
            street: buyer.street,
            city: buyer.city,
            postalCode: buyer.postalCode,
            country: buyer.country,
            vatId: buyer.vatId,
          ),
      for (final s in suppliers)
        if (s.number.isNotEmpty)
          safTPartyKey('supplier', s.number): SafTParty(
            name: s.name,
            street: s.street,
            city: s.city,
            postalCode: s.postalCode,
            country: s.countryCode,
            vatId: s.taxIdentifier,
          ),
    };
  }

  Future<GenericJournal> _written(
    JournalPosted books,
    Map<String, SafTParty> parties,
  ) async {
    final reference = workspaceTaxReference(ref);
    if (reference == null) throw StateError('workspace context not ready');
    final me = (await ref.read(myProfileProvider.future))?.identity;
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
      contact: SafTContact(
        firstName: me?.firstName ?? '',
        lastName: me?.lastName ?? '',
        phone: me?.phone ?? '',
      ),
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
