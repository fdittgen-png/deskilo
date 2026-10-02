// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../application/save_book_profile.dart';
import '../data/supabase_book_profile_repository.dart';
import '../domain/book_profile.dart';
import '../domain/book_profile_repository.dart';

part 'book_profile_providers.g.dart';

/// #1869 — where book profiles are read and saved.
@Riverpod(keepAlive: true)
BookProfileRepository bookProfileRepository(Ref ref) =>
    SupabaseBookProfileRepository(Supabase.instance.client);

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
