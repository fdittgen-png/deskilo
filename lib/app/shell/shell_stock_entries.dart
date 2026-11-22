// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B), #4299 -- the Stock group's entries: the goods ledger's balances and
// movements, the item registry, the places and the stock settings, each for
// whoever may use its page, in a space that keeps stock. Each asks what its
// route asks (route_access.dart), so the entry, the link and the read agree.
// A leaf that has not shipped its page has no entry here: no empty pages.
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_drawer_entries.dart';

/// The Stock group's entries.
extension StockEntries on DrawerEntries {
  List<DrawerEntry> stockPages() {
    if (!features.contains(WorkspaceFeature.stockManagement)) return const [];
    final reads = may(WorkspacePermission.viewStock) || may(WorkspacePermission.manageStock);
    return [
      if (reads) ...[
        DrawerEntry('drawer-stock', Icons.inventory_2_outlined, l10n.permModuleStock, () => go('/stock'), route: '/stock'),
        DrawerEntry(
          'drawer-stock-movements',
          Icons.swap_horiz_outlined,
          l10n.stockTabMovements,
          () => go('/stock/movements'),
          route: '/stock/movements',
        ),
        DrawerEntry(
          'drawer-stock-transfers',
          Icons.local_shipping_outlined,
          l10n.stockTransfersTitle,
          () => go('/stock/transfers'),
          route: '/stock/transfers',
        ),
        DrawerEntry('drawer-stock-items', Icons.category_outlined, l10n.stockItemsTitle, () => go('/stock/items'), route: '/stock/items'),
        DrawerEntry('drawer-stock-places', Icons.place_outlined, l10n.stockPlacesTitle, () => go('/stock/places'), route: '/stock/places'),
      ],
      if (features.contains(WorkspaceFeature.stockReorder) &&
          (reads || may(WorkspacePermission.managePurchases)))
        DrawerEntry(
          'drawer-stock-reorder',
          Icons.trending_down_outlined,
          l10n.stockReorderTitle,
          () => go('/stock/reorder'),
          route: '/stock/reorder',
        ),
      if (may(WorkspacePermission.manageStock) || may(WorkspacePermission.manageConfiguration))
        DrawerEntry(
          'drawer-stock-settings',
          Icons.tune_outlined,
          l10n.stockSettingsTitle,
          () => go('/stock/settings'),
          route: '/stock/settings',
        ),
    ];
  }
}
