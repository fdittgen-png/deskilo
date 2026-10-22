// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — which generic journal a year gives: the posting engine's
// entries for the issuer that keeps a local book, serialised one CSV row per
// line. No local book, no journal: nothing is derived around the engine. A
// role the engine could not resolve stops the file and is named.
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';
import '../domain/generic_journal_csv.dart';

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

class GenericJournalExport {
  const GenericJournalExport(this._books);

  final BookProfileRepository _books;

  /// The journal of [year] in [workspaceId], from the latest local-book
  /// profile of [profiles] in force in that year.
  Future<GenericJournal> of(
    String workspaceId,
    List<BookProfile> profiles,
    int year,
  ) async {
    final local = [
      for (final p in profiles)
        if (p.authority == BookAuthority.localBook &&
            !p.effectiveFrom.isAfter(DateTime(year, 12, 31)))
          p,
    ]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    if (local.isEmpty) return const JournalNeedsLocalBook();
    final set = await _books.fetchPostings(
      workspaceId,
      local.first.issuerSiteId,
      DateTime(year),
      DateTime(year, 12, 31),
    );
    if (set.blockers.isNotEmpty) {
      return JournalBlocked([
        ...{for (final b in set.blockers) b.subject},
      ]);
    }
    return JournalFile(buildGenericJournalCsv(set.postings));
  }
}
