// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../application/generic_journal_export.dart';
import '../application/save_book_profile.dart';
import '../data/supabase_book_profile_repository.dart';
import '../domain/book_chart.dart';
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';
import 'credit_providers.dart';

part 'book_profile_providers.g.dart';

/// #1869 — where book profiles are read and saved.
@Riverpod(keepAlive: true)
BookProfileRepository bookProfileRepository(Ref ref) =>
    SupabaseBookProfileRepository(ref.watch(moneyClientProvider));

/// Saving a book profile (the decision the sheet asks for).
@riverpod
BookProfiles bookProfileCommands(Ref ref) =>
    BookProfiles(ref.watch(bookProfileRepositoryProvider));

/// Every version of every issuer's book profile in the current
/// workspace; invalidated after a save.
@riverpod
Future<List<BookProfile>> bookProfiles(Ref ref) async {
  final repository = ref.watch(bookProfileRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return repository.fetchBookProfiles(workspace.id);
}

/// #1869 B — every issuer's accounts and role mappings in the current
/// workspace; invalidated after a save.
@riverpod
Future<({List<BookAccount> accounts, List<BookMapping> mappings})> bookChart(
  Ref ref,
) async {
  final repository = ref.watch(bookProfileRepositoryProvider);
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) {
    return (accounts: <BookAccount>[], mappings: <BookMapping>[]);
  }
  return repository.fetchBookChart(workspace.id);
}

/// #2370 / #2365 — the generic journal of a year, from the posting engine.
final genericJournalExportProvider = Provider<GenericJournalExport>(
  (ref) => GenericJournalExport(ref.watch(bookProfileRepositoryProvider)),
);
