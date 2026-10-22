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

class GenericJournalExport {
  const GenericJournalExport(this._books);

  final BookProfileRepository _books;

  /// The journal of [year] in [workspaceId], from the latest local-book
  /// profile of [profiles] in force in that year.
  Future<GenericJournal> of(
    String workspaceId,
    List<BookProfile> profiles,
    int year,
  ) => _posted(
    workspaceId,
    profiles,
    year,
    (set, _) async => buildGenericJournalCsv(set.postings),
  );

  /// #2365 — the FEC of [year] from the same postings, on the book's own
  /// chart (its account names).
  Future<GenericJournal> fecOf(
    String workspaceId,
    List<BookProfile> profiles,
    int year,
  ) => _posted(
    workspaceId,
    profiles,
    year,
    (set, issuer) async {
      final chart = await _books.fetchBookChart(workspaceId);
      final parties = await _books.fetchPostingParties(workspaceId, [
        ...{for (final p in set.postings) p.documentId},
      ]);
      return buildFecFromPostings(
        set.postings,
        accountNames: {
          for (final a in chart.accounts)
            if (a.issuerSiteId == issuer) a.code: a.name,
        },
        parties: parties,
      );
    },
  );

  Future<GenericJournal> _posted(
    String workspaceId,
    List<BookProfile> profiles,
    int year,
    Future<String> Function(PostingSet set, String issuerSiteId) write,
  ) async {
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
    return JournalFile(await write(set, local.issuerSiteId));
  }
}
