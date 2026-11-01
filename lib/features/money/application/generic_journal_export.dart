// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — which generic journal a year gives: the posting engine's
// entries for the issuer that keeps a local book, serialised one CSV row per
// line, or (#2365) as the FEC of that book. No local book, no journal:
// nothing is derived around the engine. A role the engine could not resolve
// stops the file and is named.
import 'dart:convert';

import '../domain/accounting_format.dart';
import '../domain/book_chart.dart';
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';
import '../domain/datev_creditors.dart';
import '../domain/fec_import_contract.dart';
import '../domain/fec_postings.dart';
import '../domain/fiscal_year.dart';
import '../domain/generic_journal_csv.dart';
import '../domain/posting.dart';
import '../domain/saf_t_financial.dart';
import '../domain/sage.dart';

/// What a year's journal is.
sealed class GenericJournal {
  const GenericJournal();
}

/// The file.
final class JournalFile extends GenericJournal {
  const JournalFile(this.content);
  final String content;
}

/// No issuer keeps a local book in the year.
final class JournalNeedsLocalBook extends GenericJournal {
  const JournalNeedsLocalBook();
}

/// These roles have no usable account; nothing was written.
final class JournalBlocked extends GenericJournal {
  const JournalBlocked(this.roles);
  final List<String> roles;
}

/// Documents in another currency than the space's that have no recorded
/// exchange rate (`reference (currency)`); nothing was written.
final class JournalNeedsRates extends GenericJournal {
  const JournalNeedsRates(this.documents);
  final List<String> documents;
}

/// #2376 — the FEC of the postings was refused: these parties have no
/// usable auxiliary account, or these documents no recorded rate.
final class JournalRefused extends GenericJournal {
  const JournalRefused(this.blockers);
  final List<FecBlocker> blockers;
}

/// #2379 — the postings before the fiscal year (the opening balances) could
/// not be posted: the roles to map or the documents without a rate, for the
/// [period] named.
final class JournalOpeningRefused extends GenericJournal {
  const JournalOpeningRefused(this.period, this.subjects);
  final FiscalYear period;
  final List<String> subjects;
}

/// #2379 — the SAF-T Financial file was refused: each missing fact named.
final class JournalSafTRefused extends GenericJournal {
  const JournalSafTRefused(this.gaps);
  final List<SafTGap> gaps;
}

/// #2377 — the Swiss journal's taxed rows of these keys (`tax:standard`)
/// have no MWST code in the tax reference; nothing was written.
final class JournalTaxCodesMissing extends GenericJournal {
  const JournalTaxCodesMissing(this.keys);
  final List<String> keys;
}

/// #2373 — the Sage 50 audit trail was refused: each blocker named.
final class JournalSageRefused extends GenericJournal {
  const JournalSageRefused(this.blockers);
  final List<SageBlocker> blockers;
}

/// The latest local-book profile of [profiles] in force in [year]; null
/// when no issuer keeps a local book then.
BookProfile? localBookOf(List<BookProfile> profiles, int year) => ([
  for (final p in profiles)
    if (p.authority == BookAuthority.localBook &&
        !p.effectiveFrom.isAfter(DateTime(year, 12, 31)))
      p,
]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom))).firstOrNull;

/// #2365 — the postings of a year, read ONCE, before any file is written:
/// with, for the FEC, the book chart's account names and the third parties
/// of its documents. Every posted format is written from this one answer.
final class JournalPosted extends GenericJournal {
  const JournalPosted(
    this.postings, {
    required this.year,
    this.accountNames = const {},
    this.parties = const {},
    this.functionalCurrency,
    this.opening = const [],
    this.accountTypes = const {},
  });
  final List<Posting> postings;

  /// #2379 — every posting of the book before [year], read once beside it
  /// for a file that states opening balances (SAF-T Financial); empty for
  /// the others.
  final List<Posting> opening;

  /// #2379 — the type of each account of the chart, by code.
  final Map<String, AccountType> accountTypes;

  /// #2376 — the fiscal year the postings were read for, on the book
  /// profile's start day: the FEC's period and its closing date.
  final FiscalYear year;
  final Map<String, String> accountNames;
  final Map<String, PostingParty> parties;

  /// The book's currency; an entry in another one needs a recorded rate.
  final String? functionalCurrency;
}

/// #2376 — the posted FEC was written but breaks the import contract a
/// French importer applies; it is not saved.
final class JournalContractBroken extends GenericJournal {
  const JournalContractBroken(this.report);
  final FecContractReport report;
}

/// [read] written by [write]; no local book or a blocked role passes through.
GenericJournal writtenWith(
  GenericJournal read,
  String Function(JournalPosted books) write,
) => read is JournalPosted ? JournalFile(write(read)) : read;

/// The generic journal CSV, one row per posting line.
String journalCsvOf(JournalPosted books) =>
    buildGenericJournalCsv(books.postings);

/// The FEC target's rule for a party's client code.
final CustomerIdRule _fecPartyRule = accountingTargets
    .firstWhere((t) => t.id == 'fec')
    .customerIdRule;

/// #2365 — the FEC of the postings, on the book's own chart; #2376 the
/// auxiliary accounts and the book's currency, or why it was refused. An
/// entry the engine converted at its document's recorded rate carries its
/// original amount (Montantdevise / Idevise); an entry still in another
/// currency than the book's is refused rather than written in it.
GenericJournal postedFecOf(JournalPosted books) {
  final fec = buildFecFromPostings(
    books.postings,
    accountNames: books.accountNames,
    parties: books.parties,
    partyRule: _fecPartyRule,
    functionalCurrency: books.functionalCurrency,
  );
  if (fec.blockers.isNotEmpty) return JournalRefused(fec.blockers);
  final contract = checkFecImportContract(
    utf8.encode(fec.file),
    year: books.year,
    thirdPartyAccounts: thirdPartyAccountsOf(books),
    knownAccounts: books.accountNames.isEmpty
        ? null
        : books.accountNames.keys.toSet(),
  );
  return contract.passed
      ? JournalFile(fec.file)
      : JournalContractBroken(contract);
}

/// The collective accounts of [books] whose lines name a third party: the
/// accounts its customers and suppliers lines are booked on.
Set<String> thirdPartyAccountsOf(JournalPosted books) => {
  for (final p in books.postings)
    for (final l in p.lines)
      if (l.role == BookRole.customers || l.role == BookRole.suppliers)
        l.accountCode,
};

/// #2375 — the purchases side [read] gives DATEV: the engine's entries and
/// their suppliers, or the roles and rates that stopped it; null when no
/// issuer keeps a local book (the export then has no supplier rows).
DatevPurchases? datevPurchasesOf(GenericJournal? read, int creditorBase) =>
    switch (read) {
      JournalPosted(:final postings, :final parties) => DatevPurchases(
        creditorBase: creditorBase,
        postings: postings,
        parties: parties,
      ),
      JournalBlocked(:final roles) => DatevPurchases(
        creditorBase: creditorBase,
        blocked: roles,
      ),
      JournalNeedsRates(:final documents) => DatevPurchases(
        creditorBase: creditorBase,
        blocked: documents,
      ),
      _ => null,
    };

/// [read]'s posted FEC: the file, or why there is none.
GenericJournal postedFecFileOf(GenericJournal read) =>
    read is JournalPosted ? postedFecOf(read) : read;

class GenericJournalExport {
  const GenericJournalExport(this._books);

  final BookProfileRepository _books;

  /// The postings of the fiscal year holding [asOf] (the export's latest
  /// document; 31 December of [year] when there is none) in [workspaceId]
  /// (`compute_postings`), from the latest local-book profile of
  /// [profiles] in force in [year]: ONE read for the period, cut on the
  /// profile's fiscal year (#2376). [named] adds the chart's account names
  /// and the documents' parties, which the FEC writes beside each line.
  /// #2379 — [withOpening] also reads, once, every posting of the book from
  /// its first day to the eve of that fiscal year: the opening balances.
  Future<GenericJournal> read(
    String workspaceId,
    List<BookProfile> profiles,
    int year, {
    bool named = false,
    bool withOpening = false,
    DateTime? asOf,
  }) async {
    final local = localBookOf(profiles, year);
    if (local == null) return const JournalNeedsLocalBook();
    final period = bookYearOf(local, asOf ?? DateTime(year, 12, 31));
    final journal = (await _readYears(workspaceId, local, [
      period,
    ], named: named)).single;
    if (!withOpening || journal is! JournalPosted) return journal;
    final start = _bookStart(profiles, local);
    if (!start.isBefore(period.from)) return journal;
    final eve = DateTime(
      period.from.year,
      period.from.month,
      period.from.day - 1,
    );
    // The opening period needs its postings and its parties, not the chart
    // a second time.
    final opening = (await _readYears(workspaceId, local, [
      FiscalYear(start, eve),
    ], named: false)).single;
    if (opening is! JournalPosted) {
      return JournalOpeningRefused(FiscalYear(start, eve), switch (opening) {
        JournalBlocked(:final roles) => roles,
        JournalNeedsRates(:final documents) => documents,
        _ => const <String>[],
      });
    }
    final parties = named && opening.postings.isNotEmpty
        ? await _books.fetchPostingParties(workspaceId, [
            ...{for (final p in opening.postings) p.documentId},
          ])
        : const <String, PostingParty>{};
    return JournalPosted(
      journal.postings,
      year: journal.year,
      accountNames: journal.accountNames,
      parties: {...parties, ...journal.parties},
      functionalCurrency: journal.functionalCurrency,
      opening: opening.postings,
      accountTypes: journal.accountTypes,
    );
  }

  /// The first day the issuer of [local] kept a local book: the earliest of
  /// its unbroken run of local-book profiles up to [local].
  DateTime _bookStart(List<BookProfile> profiles, BookProfile local) {
    final own = [
      for (final p in profiles)
        if (p.issuerSiteId == local.issuerSiteId &&
            !p.effectiveFrom.isAfter(local.effectiveFrom))
          p,
    ]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    var start = local.effectiveFrom;
    for (final p in own) {
      if (p.authority != BookAuthority.localBook) break;
      start = p.effectiveFrom;
    }
    return start;
  }

  /// The year archive's books: the postings of every fiscal year the
  /// calendar [year] overlaps up to [asOf] (the export's latest document),
  /// oldest first. With a fiscal year that is not the calendar one, the
  /// year that closes inside [year] travels beside the one still running,
  /// so the archive of [year] holds every entry its register lists. Each
  /// year is read exactly as [read] reads it, so its FEC is byte for byte
  /// the one the FEC export writes and logs; the chart and the parties are
  /// read once for all of them.
  Future<List<GenericJournal>> readArchiveYears(
    String workspaceId,
    List<BookProfile> profiles,
    int year, {
    DateTime? asOf,
  }) async {
    final local = localBookOf(profiles, year);
    if (local == null) return const [JournalNeedsLocalBook()];
    final periods = {
      bookYearOf(local, DateTime(year)),
      bookYearOf(local, asOf ?? DateTime(year, 12, 31)),
    }.toList()..sort((a, b) => a.from.compareTo(b.from));
    return _readYears(workspaceId, local, periods, named: true);
  }

  /// One postings read per period of [periods]; a period whose engine
  /// blocked is named, the others are posted.
  Future<List<GenericJournal>> _readYears(
    String workspaceId,
    BookProfile local,
    List<FiscalYear> periods, {
    required bool named,
  }) async {
    final sets = [
      for (final period in periods)
        await _books.fetchPostings(
          workspaceId,
          local.issuerSiteId,
          period.from,
          period.to,
        ),
    ];
    final posted = [
      for (final set in sets)
        if (set.blockers.isEmpty) set,
    ];
    final chart = named && posted.isNotEmpty
        ? await _books.fetchBookChart(workspaceId)
        : null;
    final parties = named && posted.isNotEmpty
        ? await _books.fetchPostingParties(workspaceId, [
            ...{
              for (final set in posted)
                for (final p in set.postings) p.documentId,
            },
          ])
        : const <String, PostingParty>{};
    return [
      for (var i = 0; i < periods.length; i++)
        _journalOf(
          sets[i],
          periods[i],
          local,
          chart: chart,
          parties: parties,
        ),
    ];
  }

  GenericJournal _journalOf(
    PostingSet set,
    FiscalYear period,
    BookProfile local, {
    required ({List<BookAccount> accounts, List<BookMapping> mappings})? chart,
    required Map<String, PostingParty> parties,
  }) {
    if (set.blockers.isNotEmpty) {
      final roles = {
        for (final b in set.blockers)
          if (b.block != PostingBlock.missingRate) b.subject,
      };
      return roles.isNotEmpty
          ? JournalBlocked([...roles])
          : JournalNeedsRates([for (final b in set.blockers) b.subject]);
    }
    if (chart == null) return JournalPosted(set.postings, year: period);
    final documents = {for (final p in set.postings) p.documentId};
    return JournalPosted(
      set.postings,
      year: period,
      functionalCurrency: local.functionalCurrency,
      accountNames: {
        for (final a in chart.accounts)
          if (a.issuerSiteId == local.issuerSiteId) a.code: a.name,
      },
      accountTypes: {
        for (final a in chart.accounts)
          if (a.issuerSiteId == local.issuerSiteId) a.code: a.type,
      },
      parties: {
        for (final e in parties.entries)
          if (documents.contains(e.key)) e.key: e.value,
      },
    );
  }
}
