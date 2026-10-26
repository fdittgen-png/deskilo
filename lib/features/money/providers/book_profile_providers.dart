// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../application/accounting_export_source.dart';
import '../application/generic_journal_export.dart';
import '../application/save_book_profile.dart';
import '../data/supabase_book_profile_repository.dart';
import '../domain/accounting_connection.dart';
import '../domain/book_chart.dart';
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';
import 'credit_providers.dart';
import 'money_queries_providers.dart';

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

/// #2365 — what one accounting export reads: the one source response of the
/// year, and for a posted format the postings of the posting engine.
/// #2370 — what the accounting systems sheet needs of the space: its
/// country, its issuers, the reader's rights and the members' names.
final accountingSystemsScopeProvider = Provider.autoDispose<AccountingSystemsScope>(
  (ref) => AccountingSystemsScope(
    countryCode: ref.watch(currentWorkspaceProvider).value?.countryCode ?? '',
    issuers: {
      for (final s in [...?ref.watch(sitesProvider).value]) s.id: s.name,
    },
    permissions: {for (final p in ref.watch(myPermissionsProvider)) p.wireName},
    memberNames: ref.watch(memberNamesProvider).value ?? const {},
  ),
);

final accountingExportSourceProvider = Provider<AccountingExportSource>(
  (ref) => AccountingExportSource(
    ref.watch(accountingSourceQueriesProvider),
    () => GenericJournalExport(ref.read(bookProfileRepositoryProvider)),
  ),
);
