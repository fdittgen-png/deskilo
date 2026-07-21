// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_accessory_repository.dart';
import '../domain/accessory.dart';
import '../domain/accessory_repository.dart';

part 'accessory_providers.g.dart';

@Riverpod(keepAlive: true)
AccessoryRepository accessoryRepository(Ref ref) =>
    SupabaseAccessoryRepository(Supabase.instance.client);

/// Accessory catalog of the active workspace, ordered by sort_order then
/// name. The catalog editor (#167) passes [includeInactive]; booking
/// display (#169) and the seat editor (#168) use the active-only default.
@riverpod
Future<List<Accessory>> accessories(
  Ref ref, {
  bool includeInactive = false,
}) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(accessoryRepositoryProvider).fetchAccessories(
        workspace.id,
        includeInactive: includeInactive,
      );
}

/// seat id → assigned accessory ids across the active workspace (one
/// fetch feeds the seat editor #168 and the booking display #169).
@riverpod
Future<Map<String, Set<String>>> seatAccessories(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  return ref
      .watch(accessoryRepositoryProvider)
      .fetchSeatAccessories(workspace.id);
}
