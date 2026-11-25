// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- one item of the stock at its own address, `/stock/items/<id>`. From the expanded window class on, the
// item stands beside the items list (ListDetailScaffold) and its address draws nothing of its own; below, it is a
// page pushed over the list. The item is read from the registry the list reads (the same walk, read on until the
// item's rows are in), its price and VAT from its service; a registry that could not be read says so, and an item
// the reader cannot see is said in words, never shown empty.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/list_detail_route.dart';
import '../../../core/ui/adaptive/page_measures.dart';
import '../../../core/ui/adaptive/window_class.dart';
import '../../../core/ui/loading_view.dart';
import '../../money/domain/service_item.dart';
import '../../money/providers/money_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_providers.dart';
import 'stock_item_view.dart';
import 'stock_read_failed.dart';

/// Whether the window holds an item beside the items list: from the expanded window class (a tablet on its side,
/// a desk).
bool stockItemBesideList(BuildContext context) =>
    WindowClass.of(context).atLeast(WindowClass.expanded);

/// The page of the item [state] names: nothing drawn where the list holds it beside itself, else the item as a page
/// of its own.
Page<void> stockItemRoutePage(BuildContext context, GoRouterState state) =>
    stockItemBesideList(context)
    ? besidePage(state)
    : MaterialPage<void>(
        key: state.pageKey,
        child: StockItemPage(itemId: state.pathParameters['itemId'] ?? ''),
      );

/// One item: its overview, its stock, its group and tags, its variants and its supplier articles.
class StockItemPage extends ConsumerWidget {
  const StockItemPage({super.key, required this.itemId, this.onClose});

  final String itemId;

  /// Set when the item stands beside the list: its close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final filter = (
      workspaceId: workspaceId ?? '',
      placeId: null,
      noHome: false,
    );
    final walk = workspaceId == null
        ? null
        : ref.watch(stockRegistryWalkProvider(filter));
    final rows = walk == null
        ? const <StockRegistryRow>[]
        : [
            for (final r in walk.rows)
              if (r.itemId == itemId) r,
          ];
    final services =
        ref.watch(allServicesProvider).value ?? const <ServiceItem>[]; // empty-ok: an unread service leaves the registry's name and price, and no Edit
    final service = services.where((s) => s.id == itemId).firstOrNull;
    Widget body;
    if (walk == null) {
      body = const LoadingView();
    } else {
      final notifier = ref.read(stockRegistryWalkProvider(filter).notifier);
      // The registry is read by name, so an item's rows stand together: read on while none is found yet, or while the
      // last row read is still this item's (its next variant may be on the next page).
      if (walk.error == null &&
          walk.canLoadMore &&
          (rows.isEmpty || walk.rows.last.itemId == itemId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) unawaited(notifier.loadMore());
        });
      }
      body = rows.isNotEmpty
          ? StockItemView(
              workspaceId: workspaceId!,
              itemId: itemId,
              rows: rows,
              service: service,
              services: services,
            )
          : walk.error != null
          ? Center(
              child: StockReadFailed(
                keyName: 'stock-item',
                error: walk.error!,
                onRetry: walk.rows.isEmpty
                    ? () => unawaited(notifier.reload())
                    : () => unawaited(notifier.loadMore()),
              ),
            )
          : walk.loading || walk.canLoadMore
          ? const LoadingView()
          : Center(
              child: Text(
                l10n.searchRecordUnreadable,
                key: const ValueKey('stock-item-unreadable'),
              ),
            );
    }
    return Scaffold(
      key: ValueKey('stock-item-page-$itemId'),
      appBar: AppBar(
        title: Text(
          service?.name ?? rows.firstOrNull?.itemName ?? l10n.stockItemsTitle,
          overflow: TextOverflow.ellipsis,
        ),
        automaticallyImplyLeading: onClose == null,
        actions: [
          HelpDot(l10n.stockItemsTitle, anchor: HelpAnchor.moneyStockItem),
          if (onClose case final close?)
            CloseButton(
              key: const ValueKey('stock-item-close'),
              onPressed: close,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
          child: body,
        ),
      ),
    );
  }
}
