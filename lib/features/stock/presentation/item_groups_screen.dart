// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- Item groups (`/stock/groups`): the groups of the stock with their sub-groups, the settings each
// one carries and how many items belong to it. Whoever may manage the stock adds a group and opens one to change
// it (the server asks the same); a person who may only look reads them. A read that fails says so and offers
// Try again: it is never an empty list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/item_groups.dart';
import '../domain/stock_config.dart';
import '../domain/stock_service_creator.dart';
import '../providers/stock_providers.dart';
import 'item_group_sheet.dart';
import 'item_group_text.dart';

class ItemGroupsScreen extends ConsumerWidget {
  const ItemGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.itemGroupsTitle),
        actions: [HelpDot(l10n.itemGroupsTitle, anchor: HelpAnchor.moneyStockGroups)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ref.watch(itemGroupListProvider(workspaceId)).when(
                  loading: () => const LoadingView(),
                  error: (_, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.itemGroupFailed, key: const ValueKey('item-groups-failed')),
                      TextButton(
                        key: const ValueKey('item-groups-retry'),
                        onPressed: () => ref.invalidate(itemGroupListProvider(workspaceId)),
                        child: Text(l10n.identityConnectRetry),
                      ),
                    ],
                  ),
                  data: (groups) => _GroupList(workspaceId: workspaceId, groups: groups, mayManage: mayManage),
                ),
              ),
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
    var places = const <StockPlaceConfig>[];
    try {
      places = await ref.read(stockPlaceConfigsProvider(workspaceId).future);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the places could not be read for a group', error: e, stackTrace: st);
    }
    // what an item costs or sells for: only for someone who may manage services AND see the finances
    final held = ref.read(myPermissionsProvider);
    final finance = held.contains(WorkspacePermission.manageServices) && held.contains(WorkspacePermission.viewFinances);
    final vat = finance ? await ref.read(stockServiceCreatorProvider)?.vatChoices(workspaceId) ?? const <StockVatChoice>[] : const <StockVatChoice>[];
    if (!context.mounted) return;
    final saved = await showItemGroupSheet(context, ref.read(itemGroupsProvider), workspaceId: workspaceId, group: group, groups: groups, choices: (places: places, vat: vat, finance: finance));
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
