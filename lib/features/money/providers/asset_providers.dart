// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2576 — the equipment register.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/asset_commands.dart';
import '../data/supabase_workspace_asset_repository.dart';
import '../domain/workspace_asset.dart';
import 'credit_providers.dart';

final workspaceAssetRepositoryProvider = Provider<WorkspaceAssetRepository>(
  (ref) => SupabaseWorkspaceAssetRepository(ref.watch(moneyClientProvider)),
);

/// Registering equipment and deciding its treatment.
final assetCommandProvider = Provider<AssetCommands>(
  (ref) => AssetCommands(ref.watch(workspaceAssetRepositoryProvider)),
);

/// The register of one workspace, by number.
final workspaceAssetsProvider = FutureProvider.autoDispose
    .family<List<WorkspaceAsset>, String>(
      (ref, workspaceId) =>
          ref.watch(workspaceAssetRepositoryProvider).fetchAssets(workspaceId),
    );

/// The equipment lines nobody has registered yet.
final assetCandidateLinesProvider = FutureProvider.autoDispose
    .family<List<AssetCandidateLine>, String>(
      (ref, workspaceId) => ref
          .watch(workspaceAssetRepositoryProvider)
          .fetchCandidateLines(workspaceId),
    );
