// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- Items: the item registry of the stock, on a page of its own
// (`/stock/items`). Each item opens its settings, its variants and its supplier
// articles; a person who may only look sees the list and no editor. A list that
// could not be read says so: it is never shown as "no items".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_item_editor.dart';
import 'stock_mapping_editor.dart';
import 'stock_variants_editor.dart';

class StockItemsScreen extends ConsumerWidget {
  const StockItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockItemsTitle),
        actions: [HelpDot(l10n.permModuleStock, anchor: HelpAnchor.moneyStock)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.stockItemsIntro, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(child: _Items(workspaceId: workspaceId)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Items extends ConsumerWidget {
  const _Items({required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(stockItemsProvider(workspaceId))
        .when(
          loading: () => const LoadingView(),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.stockReadFailed, key: const ValueKey('stock-items-failed')),
                const FormGap(),
                OutlinedButton(
                  key: const ValueKey('stock-items-retry'),
                  onPressed: () => ref.invalidate(stockItemsProvider(workspaceId)),
                  child: Text(l10n.identityConnectRetry),
                ),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(l10n.stockItemsEmpty, key: const ValueKey('stock-items-empty'), textAlign: TextAlign.center),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ItemRow(workspaceId: workspaceId, item: items[i]),
                ),
        );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.workspaceId, required this.item});

  final String workspaceId;
  final StockItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #4169: the editors are for a person who may manage the stock; the server
    // asks the same.
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final lotsOn = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockLots);
    return ListTile(
      key: ValueKey('stock-item-${item.id}'),
      title: Text(item.name),
      subtitle: item.unit.isEmpty ? null : Text(item.unit),
      trailing: !mayManage
          ? null
          : Wrap(
              children: [
                IconButton(
                  key: ValueKey('stock-edit-item-${item.id}'),
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.stockEditItem,
                  onPressed: () => showStockItemEditor(
                    context,
                    ref.read(stockConfigCommandsProvider),
                    workspaceId: workspaceId,
                    itemId: item.id,
                    itemName: item.name,
                    lotsOn: lotsOn,
                  ),
                ),
                IconButton(
                  key: ValueKey('stock-edit-variants-${item.id}'),
                  icon: const Icon(Icons.style_outlined),
                  tooltip: l10n.stockVariantsEdit,
                  onPressed: () => showStockVariantsEditor(
                    context,
                    ref.read(stockConfigCommandsProvider),
                    workspaceId: workspaceId,
                    itemId: item.id,
                    itemName: item.name,
                  ),
                ),
                IconButton(
                  key: ValueKey('stock-edit-mappings-${item.id}'),
                  icon: const Icon(Icons.link),
                  tooltip: l10n.stockMappingsEdit,
                  onPressed: () => showStockMappings(
                    context,
                    ref.read(stockConfigCommandsProvider),
                    workspaceId: workspaceId,
                    itemId: item.id,
                    itemName: item.name,
                  ),
                ),
              ],
            ),
    );
  }
}
