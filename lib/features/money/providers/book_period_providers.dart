// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the periods of the books and the log of accounting exports.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../application/book_period_commands.dart';
import '../data/supabase_book_period_repository.dart';
import 'credit_providers.dart';

final bookPeriodRepositoryProvider = Provider<BookPeriodRepository>(
  (ref) => SupabaseBookPeriodRepository(
    ref.watch(moneyClientProvider),
    appVersion: () => ref.read(appVersionProvider.future),
  ),
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
