// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- Item groups (`/stock/groups`): the groups of the stock with their sub-groups, the settings each
// one carries and how many items belong to it. Whoever may manage the stock adds a group and opens one to change
// it (the server asks the same); a person who may only look reads them. A read that fails says so and offers
// Try again: it is never an empty list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/item_groups.dart';
import '../domain/stock_config.dart';
import '../domain/stock_page.dart' show StockItem;
import '../domain/stock_service_creator.dart';
import '../providers/stock_providers.dart';
import '../providers/workspace_units_providers.dart';
import 'item_group_sheet.dart';
import 'item_group_text.dart';
import 'stock_page_shell.dart';

class ItemGroupsScreen extends ConsumerWidget {
  const ItemGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    return StockPageShell(
      title: l10n.itemGroupsTitle,
      anchor: HelpAnchor.moneyStockGroups,
      reading: true,
      body: (context, ref, workspaceId) => StockRead(
        keyName: 'item-groups',
        value: ref.watch(itemGroupListProvider(workspaceId)),
        onRetry: () => ref.invalidate(itemGroupListProvider(workspaceId)),
        data: (groups) => _GroupList(workspaceId: workspaceId, groups: groups, mayManage: mayManage),
      ),
    );
  }
}

class _GroupList extends ConsumerWidget {
  const _GroupList({required this.workspaceId, required this.groups, required this.mayManage});

  final String workspaceId;
  final List<ItemGroup> groups;
  final bool mayManage;

  Future<void> _open(BuildContext context, WidgetRef ref, ItemGroup? group) async {
    // the home zones are a choice, not a need: a failed read opens the sheet without them
    final places = await guardRead(
      domain: 'stock',
      message: 'the places could not be read for a group',
      read: () => ref.read(stockPlaceConfigsProvider(workspaceId).future),
      fallback: (_) => const <StockPlaceConfig>[],
    );
    // what an item costs or sells for: only for someone who may manage services AND see the finances
    final held = ref.read(myPermissionsProvider);
    final finance = held.contains(WorkspacePermission.manageServices) && held.contains(WorkspacePermission.viewFinances);
    final vat = finance ? await ref.read(stockServiceCreatorProvider)?.vatChoices(workspaceId) ?? const <StockVatChoice>[] : const <StockVatChoice>[];
    // the deposit item is a choice too
    var items = const <StockItem>[];
    try {
      items = await ref.read(stockItemsProvider(workspaceId).future);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the items could not be read for a group', error: e, stackTrace: st);
    }
    final units = await pickableUnitsOf(ref, workspaceId, keep: group?.params['inventory_unit'] as String?);
    if (!context.mounted) return;
    final saved = await showItemGroupSheet(context, ref.read(itemGroupsProvider), workspaceId: workspaceId, group: group, groups: groups, choices: (places: places, vat: vat, finance: finance, items: items, units: units));
    if (saved) ref.invalidate(itemGroupListProvider(workspaceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (mayManage)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('item-group-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.itemGroupsAdd),
              onPressed: () => _open(context, ref, null),
            ),
          ),
        if (groups.isEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(l10n.itemGroupsEmpty, key: const ValueKey('item-groups-empty'))),
        for (final g in groups)
          ListTile(
            key: ValueKey('item-group-${g.id}'),
            contentPadding: EdgeInsets.only(left: g.parentId == null ? 0 : 32),
            leading: Icon(g.parentId == null ? Icons.folder_outlined : Icons.subdirectory_arrow_right),
            title: Text(g.name),
            subtitle: Text([l10n.stockCyclePlanItemsCount(g.items), itemGroupSummary(l10n, g)].where((t) => t.isNotEmpty).join(' · ')),
            onTap: mayManage ? () => _open(context, ref, g) : null,
          ),
      ],
    );
  }
}
