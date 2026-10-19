// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the periods of the books and the log of accounting exports.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/book_period_commands.dart';
import '../data/supabase_book_period_repository.dart';
import '../domain/book_period.dart';
import 'credit_providers.dart';

final bookPeriodRepositoryProvider = Provider<BookPeriodRepository>(
  (ref) => SupabaseBookPeriodRepository(ref.watch(moneyClientProvider)),
);

/// Closing and reopening a period.
final bookPeriodCommandProvider = Provider<BookPeriodCommands>(
  (ref) => BookPeriodCommands(ref.watch(bookPeriodRepositoryProvider)),
);

/// The periods and the export log of one workspace.
final bookPeriodsProvider = FutureProvider.autoDispose
    .family<BookPeriodsOverview, String>(
      (ref, workspaceId) =>
          ref.watch(bookPeriodRepositoryProvider).fetch(workspaceId),
    );
