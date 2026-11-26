// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4483 -- what can be done to an item of the stock, declared once: the editor each action opens (the ones the
// business already has, never a second), the key the recorder and the tests know it by, its icon and its words,
// and whether the member's rights allow it (`manageServices` for name, price and VAT, `manageStock` for the rest, as
// the server decides). The item's page (#4480), the phone's chips and the desk's toolbar all act through it, so an
// action opens the same editor with the same key wherever it is reached, and a save reads the registry again.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../money/domain/service_item.dart';
import '../../money/presentation/widgets/service_sheet.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_config.dart';
import '../domain/stock_registry.dart';
import '../domain/stock_tags.dart';
import '../providers/stock_item_providers.dart';
import '../providers/stock_providers.dart';
import 'item_group_assign_dialog.dart';
import 'stock_home_sheet.dart';
import 'stock_item_editor.dart';
import 'stock_mapping_editor.dart';
import 'stock_tags_dialog.dart';
import 'stock_variants_editor.dart';

/// Reads the registry again, from its first page: the list and the item's page show what was saved.
void reloadStockRegistry(WidgetRef ref) =>
    ref.invalidate(stockRegistryWalkProvider);

/// The actions of an item, in the order they are offered.
enum StockItemActionKind {
  details,
  home,
  group,
  tags,
  settings,
  variants,
  suppliers,
}

/// The key of the action [kind] on [row]: the home place is the row's (an item or one of its variants), every
/// other action the item's.
ValueKey<String> stockItemActionKey(
  StockItemActionKind kind,
  StockRegistryRow row,
) => switch (kind) {
  StockItemActionKind.details => ValueKey('stock-item-edit-${row.itemId}'),
  StockItemActionKind.home => ValueKey('stock-home-${row.key}'),
  StockItemActionKind.group => ValueKey('stock-item-group-${row.itemId}'),
  StockItemActionKind.tags => ValueKey('stock-tags-${row.itemId}'),
  StockItemActionKind.settings => ValueKey('stock-edit-item-${row.itemId}'),
  StockItemActionKind.variants => ValueKey('stock-edit-variants-${row.itemId}'),
  StockItemActionKind.suppliers => ValueKey(
    'stock-edit-mappings-${row.itemId}',
  ),
};

/// One action on one row: what it is, how it is shown and what it does.
@immutable
class StockItemAction {
  const StockItemAction({
    required this.kind,
    required this.key,
    required this.icon,
    required this.word,
    required this.label,
    required this.allowed,
    required this.run,
  });

  final StockItemActionKind kind;
  final ValueKey<String> key;
  final IconData icon;

  /// The short word of a chip on the phone.
  final String word;

  /// The words of the desk toolbar's button.
  final String label;

  /// Whether the member's rights allow it.
  final bool allowed;

  /// Opens the action's editor; a save reads what it changed again.
  final Future<void> Function() run;
}

/// Opens the actions of the item and of the row it is read from, with the services the service editor proposes
/// categories from. Built in a widget's build: what decides the actions is watched.
class StockItemActions {
  StockItemActions(
    this.context,
    this.ref, {
    required this.workspaceId,
    required this.services,
  });

  final BuildContext context;
  final WidgetRef ref;
  final String workspaceId;

  /// The business's services; an item's own is its name, price and VAT.
  final List<ServiceItem> services;

  ServiceItem? serviceOf(String itemId) =>
      services.where((s) => s.id == itemId).firstOrNull;

  /// The item's name as the business calls it.
  String nameOf(StockRegistryRow row) =>
      serviceOf(row.itemId)?.name ?? row.itemName;

  /// Every action the business offers for [row] (group and tags where it keeps them), each saying whether the
  /// member may use it. Name, price and VAT are offered only where the item's service could be read.
  List<StockItemAction> of(StockRegistryRow row) {
    final l10n = context.l10n;
    final held = ref.watch(myPermissionsProvider);
    final mayStock = held.contains(WorkspacePermission.manageStock);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final service = serviceOf(row.itemId);
    StockItemAction action(
      StockItemActionKind kind,
      IconData icon,
      ({String word, String label}) words,
      Future<void> Function() run,
    ) => StockItemAction(
      kind: kind,
      key: stockItemActionKey(kind, row),
      icon: icon,
      word: words.word,
      label: words.label,
      allowed: mayStock,
      run: run,
    );
    return [
      if (service != null)
        StockItemAction(
          kind: StockItemActionKind.details,
          key: stockItemActionKey(StockItemActionKind.details, row),
          icon: Icons.edit_outlined,
          word: l10n.taskWizardEdit,
          label: l10n.stockItemEditDetails,
          allowed: held.contains(WorkspacePermission.manageServices),
          run: () => editService(service),
        ),
      action(StockItemActionKind.home, Icons.place_outlined, (
        word: l10n.stockPlaceEditTitle,
        label: l10n.stockPlaceEditTitle,
      ), () => editHome(row)),
      if (features.contains(WorkspaceFeature.stockItemGroups))
        action(StockItemActionKind.group, Icons.folder_outlined, (
          word: l10n.documentsColGroup,
          label: l10n.documentsColGroup,
        ), () => editGroup(row)),
      if (ref.watch(stockTagsProvider))
        action(StockItemActionKind.tags, Icons.sell_outlined, (
          word: l10n.stockTagsOpen,
          label: l10n.stockTagsOpen,
        ), () => editTags(row)),
      action(StockItemActionKind.settings, Icons.tune, (
        word: l10n.settingsTitle,
        label: l10n.stockSettingsTitle,
      ), () => editSettings(row)),
      action(StockItemActionKind.variants, Icons.style_outlined, (
        word: l10n.stockItemSectionVariants,
        label: l10n.stockItemSectionVariants,
      ), () => editVariants(row)),
      action(StockItemActionKind.suppliers, Icons.local_shipping_outlined, (
        word: l10n.myBusinessSuppliers,
        label: l10n.stockItemSectionSuppliers,
      ), () => editSuppliers(row)),
    ];
  }

  /// Name, price and VAT in the service editor.
  Future<void> editService(ServiceItem service) async {
    await ServiceEditor.open(
      context,
      ref,
      workspaceId: workspaceId,
      service: service,
      categories: [for (final s in services) s.category],
    );
    if (context.mounted) reloadStockRegistry(ref);
  }

  /// The home place of [row]: the item, or one of its variants.
  Future<void> editHome(StockRegistryRow row) async {
    final saved = await showStockHomeSheet(
      context,
      ref.read(stockRegistryProvider),
      workspaceId: workspaceId,
      row: row,
      // The places only feed the choice; they are watched where the actions are shown.
      places:
          ref.read(stockPlaceConfigsProvider(workspaceId)).value ??
          const <StockPlaceConfig>[], // empty-ok: a choice
      separator: ref.read(stockAddressSeparatorProvider),
    );
    if (saved && context.mounted) reloadStockRegistry(ref);
  }

  /// The units, codes and tracking of the item.
  Future<void> editSettings(StockRegistryRow row) async {
    final saved = await showStockItemEditor(
      context,
      ref.read(stockConfigCommandsProvider),
      workspaceId: workspaceId,
      itemId: row.itemId,
      itemName: nameOf(row),
      options: (
        lots: ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.stockLots),
        keep: false,
        groups: itemGroupsIfOn(ref),
      ),
    );
    if (saved && context.mounted) reloadStockRegistry(ref);
  }

  /// The group the item is in; its name is read again.
  Future<void> editGroup(StockRegistryRow row) async {
    await showItemGroupAssign(
      context,
      workspaceId: workspaceId,
      itemId: row.itemId,
      itemName: nameOf(row),
    );
    if (!context.mounted) return;
    // The dialog may have made the group it moved the item to.
    ref
      ..invalidate(stockItemGroupListProvider(workspaceId))
      ..invalidate(
        stockItemGroupNameProvider((
          workspaceId: workspaceId,
          itemId: row.itemId,
        )),
      );
  }

  /// The tags bound to the item.
  Future<void> editTags(StockRegistryRow row) => showStockTagsDialog(
    context,
    workspaceId: workspaceId,
    owner: TagOwner.item(row.itemId),
    name: nameOf(row),
  );

  /// The item's variants; they and the registry are read again.
  Future<void> editVariants(StockRegistryRow row) async {
    final saved = await showStockVariantsEditor(
      context,
      ref.read(stockConfigCommandsProvider),
      workspaceId: workspaceId,
      itemId: row.itemId,
      itemName: nameOf(row),
    );
    if (!saved || !context.mounted) return;
    ref.invalidate(
      stockItemVariantsProvider((workspaceId: workspaceId, itemId: row.itemId)),
    );
    reloadStockRegistry(ref);
  }

  /// The supplier articles that name the item; they are read again.
  Future<void> editSuppliers(StockRegistryRow row) async {
    await showStockMappings(
      context,
      ref.read(stockConfigCommandsProvider),
      workspaceId: workspaceId,
      itemId: row.itemId,
      itemName: nameOf(row),
    );
    if (!context.mounted) return;
    ref.invalidate(
      stockItemMappingsProvider((workspaceId: workspaceId, itemId: row.itemId)),
    );
  }
}
