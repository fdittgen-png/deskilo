// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/book_chart.dart';
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';

/// What became of a save.
enum BookSaveOutcome {
  saved,

  /// Someone saved the same version since it was read; nothing written.
  stale,

  /// The profile breaks a rule; nothing sent.
  invalid,

  /// #1869 B — a local book whose required roles are not mapped for its
  /// first day; nothing sent.
  unmapped,
}

/// #1869 — saving a book profile: never sends one that breaks a rule,
/// and tells a stale save apart from a saved one.
class BookProfiles {
  const BookProfiles(this._repository);

  final BookProfileRepository _repository;

  /// Throws whatever the repository throws; the caller reports it.
  Future<BookSaveOutcome> save(
    BookProfile draft, {
    List<BookMapping> mappings = const [],
  }) async {
    if (validateBookProfile(draft).isNotEmpty) return BookSaveOutcome.invalid;
    if (draft.authority == BookAuthority.localBook &&
        missingForLocalBook(
          mappings,
          draft.issuerSiteId,
          draft.effectiveFrom,
        ).isNotEmpty) {
      return BookSaveOutcome.unmapped;
    }
    final saved = await _repository.saveBookProfile(draft);
    return saved == null ? BookSaveOutcome.stale : BookSaveOutcome.saved;
  }

  /// #1869 B — an account, checked before it is sent.
  Future<BookSaveOutcome> saveAccount(BookAccount account) async {
    if (validateBookAccount(account).isNotEmpty) return BookSaveOutcome.invalid;
    final saved = await _repository.saveBookAccount(account);
    return saved == null ? BookSaveOutcome.stale : BookSaveOutcome.saved;
  }

  /// #1869 B — the account [role] books to from [effectiveFrom]: a new
  /// version, or the correction of the version of that very day.
  Future<BookSaveOutcome> saveMapping({
    required BookRole role,
    required BookAccount account,
    required DateTime effectiveFrom,
    required List<BookMapping> current,
  }) async {
    if (mappingProblem(role, account, account.issuerSiteId) != null) {
      return BookSaveOutcome.invalid;
    }
    final day = DateTime.utc(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );
    final sameDay = current.where(
      (m) =>
          m.issuerSiteId == account.issuerSiteId &&
          m.role == role &&
          DateTime.utc(
                m.effectiveFrom.year,
                m.effectiveFrom.month,
                m.effectiveFrom.day,
              ) ==
              day,
    );
    final saved = await _repository.saveBookMapping(
      workspaceId: account.workspaceId,
      issuerSiteId: account.issuerSiteId,
      role: role,
      accountId: account.id,
      effectiveFrom: day,
      expectedRevision: sameDay.isEmpty ? 0 : sameDay.first.revision,
    );
    return saved == null ? BookSaveOutcome.stale : BookSaveOutcome.saved;
  }
}
