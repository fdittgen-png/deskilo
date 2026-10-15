// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/datev.dart';
import '../domain/datev_fields.dart';
import '../providers/book_profile_providers.dart';

/// #2365 — [accounts] with the fiscal year starting where the book
/// profiles of [year] say (every issuer agreeing); without a profile the
/// header keeps 1 January.
Future<DatevAccounts> datevAccountsFor(
  WidgetRef ref,
  DatevAccounts accounts,
  int year,
) async {
  final profiles = await ref.read(bookProfilesProvider.future);
  final start = datevProfileFiscalStart(
    profiles,
    DateTime(year),
    DateTime(year, 12, 31),
  );
  return start == null ? accounts : accounts.withFiscalYearStart(start);
}
