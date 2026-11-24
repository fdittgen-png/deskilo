// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4294 -- the names the low-stock notice of the inbox reads: each stock item and its unit, and each
// place by its address. Only while the business has the reorder feature on; otherwise nothing.
// The app hands this to the feed as a name source.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart' show stockAddress;
import '../providers/stock_providers.dart';

/// `item:<id>`, `unit:<id>` and `place:<id>` names of the current business, or none.
Future<Map<String, String>> stockEventNames(Ref ref) async {
  final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
  final on = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockReorder);
  if (workspaceId == null || !on) return const {};
  final separator = ref.watch(stockAddressSeparatorProvider);
  final itemsRead = ref.watch(stockItemsProvider(workspaceId).future);
  final placesRead = ref.watch(stockPlaceConfigsProvider(workspaceId).future);
  final items = await itemsRead;
  final places = await placesRead;
  return {
    for (final i in items) ...{'item:${i.id}': i.name, 'unit:${i.id}': i.unit},
    for (final p in places) 'place:${p.id}': p.isAddressable ? stockAddress(p, separator) : p.code,
  };
}
