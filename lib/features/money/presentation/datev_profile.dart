// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/book_profile.dart';
import '../domain/datev.dart';
import '../domain/datev_fields.dart';

/// #2365 — [accounts] with the fiscal year starting where the book
/// profiles of [year] say (every issuer agreeing); without a profile the
/// header keeps 1 January. [profiles] are the ones delivered with the books
/// of the export (the one source response), not a second, later read.
DatevAccounts datevAccountsFor(
  List<BookProfile> profiles,
  DatevAccounts accounts,
  int year,
) {
  final start = datevProfileFiscalStart(
    profiles,
    DateTime(year),
    DateTime(year, 12, 31),
  );
  return start == null ? accounts : accounts.withFiscalYearStart(start);
}
