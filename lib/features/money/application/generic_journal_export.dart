// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — which generic journal a year gives: the posting engine's
// entries for the issuer that keeps a local book, serialised one CSV row per
// line, or (#2365) as the FEC of that book. No local book, no journal:
// nothing is derived around the engine. A role the engine could not resolve
// stops the file and is named.
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';
import '../domain/fec_postings.dart';
import '../domain/generic_journal_csv.dart';
import '../domain/posting.dart';

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
    this.accountNames = const {},
    this.parties = const {},
  });
  final List<Posting> postings;
  final Map<String, String> accountNames;
  final Map<String, PostingParty> parties;
}

/// [read] written by [write]; no local book or a blocked role passes through.
GenericJournal writtenWith(
  GenericJournal read,
  String Function(JournalPosted books) write,
) => read is JournalPosted ? JournalFile(write(read)) : read;

/// The generic journal CSV, one row per posting line.
String journalCsvOf(JournalPosted books) =>
    buildGenericJournalCsv(books.postings);

/// #2365 — the FEC of the postings, on the book's own chart.
String postedFecOf(JournalPosted books) => buildFecFromPostings(
  books.postings,
  accountNames: books.accountNames,
  parties: books.parties,
);

class GenericJournalExport {
  const GenericJournalExport(this._books);

  final BookProfileRepository _books;

  /// The postings of [year] in [workspaceId] (`compute_postings`), from the
  /// latest local-book profile of [profiles] in force in that year: ONE read
  /// for the period. [named] adds the chart's account names and the
  /// documents' parties, which the FEC writes beside each line.
  Future<GenericJournal> read(
    String workspaceId,
    List<BookProfile> profiles,
    int year, {
    bool named = false,
  }) async {
    final local = localBookOf(profiles, year);
    if (local == null) return const JournalNeedsLocalBook();
    final set = await _books.fetchPostings(
      workspaceId,
      local.issuerSiteId,
      DateTime(year),
      DateTime(year, 12, 31),
    );
    if (set.blockers.isNotEmpty) {
      return JournalBlocked([
        ...{for (final b in set.blockers) b.subject},
      ]);
    }
    if (!named) return JournalPosted(set.postings);
    final chart = await _books.fetchBookChart(workspaceId);
    final parties = await _books.fetchPostingParties(workspaceId, [
      ...{for (final p in set.postings) p.documentId},
    ]);
    return JournalPosted(
      set.postings,
      accountNames: {
        for (final a in chart.accounts)
          if (a.issuerSiteId == local.issuerSiteId) a.code: a.name,
      },
      parties: parties,
    );
  }
}
