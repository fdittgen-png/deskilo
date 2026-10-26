// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../application/retention_holds.dart';
import '../data/supabase_retention_hold_repository.dart';
import '../domain/retention_hold.dart';
import 'credit_providers.dart';

part 'retention_hold_providers.g.dart';

/// Where retention holds are read, placed and released.
@Riverpod(keepAlive: true)
RetentionHoldRepository retentionHoldRepository(Ref ref) =>
    SupabaseRetentionHoldRepository(ref.watch(moneyClientProvider));

/// Placing and releasing a hold (the decision the retention dialog asks for).
@riverpod
RetentionHolds retentionHoldCommands(Ref ref) =>
    RetentionHolds(ref.watch(retentionHoldRepositoryProvider));

/// Every hold of the current workspace, the active ones first; invalidated
/// after a change.
@riverpod
Future<List<RetentionHold>> retentionHolds(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(retentionHoldRepositoryProvider).fetchHolds(workspace.id);
}
