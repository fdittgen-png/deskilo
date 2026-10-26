// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The accounting target systems: connections, mappings and transfers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/accounting_connection_commands.dart';
import '../data/supabase_accounting_connection_repository.dart';
import '../domain/accounting_connection.dart';
import 'credit_providers.dart';

final accountingConnectionRepositoryProvider =
    Provider<AccountingConnectionRepository>(
      (ref) =>
          SupabaseAccountingConnectionRepository(ref.watch(moneyClientProvider)),
    );

/// Connecting, mapping, revoking and logging what a file carried.
final accountingConnectionCommandProvider =
    Provider<AccountingConnectionCommands>(
      (ref) => AccountingConnectionCommands(
        ref.watch(accountingConnectionRepositoryProvider),
      ),
    );

/// The connections of one workspace, revoked ones last.
final accountingConnectionsProvider = FutureProvider.autoDispose
    .family<List<AccountingConnection>, String>(
      (ref, workspaceId) => ref
          .watch(accountingConnectionRepositoryProvider)
          .fetchConnections(workspaceId),
    );

/// What moved in one period of one workspace.
final accountingTransfersProvider = FutureProvider.autoDispose
    .family<
      AccountingTransfers,
      ({String workspaceId, DateTime from, DateTime to})
    >(
      (ref, key) => ref
          .watch(accountingConnectionRepositoryProvider)
          .fetchTransfers(key.workspaceId, key.from, key.to),
    );
