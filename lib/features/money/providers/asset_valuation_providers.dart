// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the accountant's valuations of the equipment.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/asset_valuation_commands.dart';
import '../data/supabase_asset_valuation_repository.dart';
import '../domain/asset_valuation.dart';
import 'credit_providers.dart';

final assetValuationRepositoryProvider = Provider<AssetValuationRepository>(
  (ref) => SupabaseAssetValuationRepository(ref.watch(moneyClientProvider)),
);

/// Staging a file and confirming a batch.
final assetValuationCommandProvider = Provider<AssetValuationCommands>(
  (ref) => AssetValuationCommands(ref.watch(assetValuationRepositoryProvider)),
);

/// The batches of one workspace.
final assetValuationBatchesProvider = FutureProvider.autoDispose
    .family<List<ValuationBatch>, String>(
      (ref, workspaceId) =>
          ref.watch(assetValuationRepositoryProvider).fetchBatches(workspaceId),
    );

/// The rows of one batch.
final assetValuationRowsProvider = FutureProvider.autoDispose
    .family<List<ValuationRow>, ({String workspaceId, String batchId})>(
      (ref, key) => ref
          .watch(assetValuationRepositoryProvider)
          .fetchRows(key.workspaceId, key.batchId),
    );
