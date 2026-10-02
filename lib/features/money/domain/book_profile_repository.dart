// SPDX-License-Identifier: AGPL-3.0-or-later
import 'book_profile.dart';

/// #1869 — where book profiles are read and saved: `book_profiles` and
/// `save_book_profile` (0335) on a server, a map in the demo and tests.
abstract class BookProfileRepository {
  /// Every version of every issuer's profile in [workspaceId].
  Future<List<BookProfile>> fetchBookProfiles(String workspaceId);

  /// Saves [profile] against the revision it was read at (0 for a new
  /// version). Null when someone saved that version since: nothing was
  /// written.
  Future<BookProfile?> saveBookProfile(BookProfile profile);
}
