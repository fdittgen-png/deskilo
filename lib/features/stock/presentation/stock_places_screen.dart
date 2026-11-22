// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- Places: the sites, zones, shelves and bins of the stock on a page of
// its own (`/stock/places`). The system's own places are shown, not editable; a
// person who may only look cannot add or edit one (the server asks the same).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../providers/stock_providers.dart';
import 'stock_place_editor.dart';

class StockPlacesScreen extends ConsumerWidget {
  const StockPlacesScreen({super.key, this.addFirst = false});

  /// #4350 -- the first-run link: the page opens with the editor of a new place.
  final bool addFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(context.l10n.stockPlacesTitle),
        actions: [HelpDot(context.l10n.permModuleStock, anchor: HelpAnchor.moneyStockPlaces)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: StockPlacesBody(
                  workspaceId: workspaceId,
                  addFirst: addFirst,
                  canEdit: ref
                      .watch(myPermissionsProvider)
                      .contains(WorkspacePermission.manageStock),
                  // recorder-key-exempt: a data callback, not a control
                  onChanged: () =>
                      ref.invalidate(stockPlacesProvider(workspaceId)),
                ),
              ),
            ),
    );
  }
}
