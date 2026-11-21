// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- the Stock group's entry: the records of the goods ledger, for
// whoever may see or move the stock, in a space that keeps it. It asks what
// its route asks (route_access.dart), so the entry, the link and the read
// agree.
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_drawer_entries.dart';

/// The Stock group's entries.
extension StockEntries on DrawerEntries {
  List<DrawerEntry> stockPages() => [
    if (features.contains(WorkspaceFeature.stockManagement) &&
        (may(WorkspacePermission.viewStock) ||
            may(WorkspacePermission.manageStock)))
      DrawerEntry(
        'drawer-stock',
        Icons.inventory_2_outlined,
        l10n.permModuleStock,
        () => go('/stock'),
        route: '/stock',
      ),
  ];
}
