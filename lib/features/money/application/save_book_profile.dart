// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';

/// What became of a save.
enum BookSaveOutcome {
  saved,

  /// Someone saved the same version since it was read; nothing written.
  stale,

  /// The profile breaks a rule; nothing sent.
  invalid,
}

/// #1869 — saving a book profile: never sends one that breaks a rule,
/// and tells a stale save apart from a saved one.
class BookProfiles {
  const BookProfiles(this._repository);

  final BookProfileRepository _repository;

  /// Throws whatever the repository throws; the caller reports it.
  Future<BookSaveOutcome> save(BookProfile draft) async {
    if (validateBookProfile(draft).isNotEmpty) return BookSaveOutcome.invalid;
    final saved = await _repository.saveBookProfile(draft);
    return saved == null ? BookSaveOutcome.stale : BookSaveOutcome.saved;
  }
}
