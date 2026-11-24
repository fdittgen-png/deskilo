// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- Stock: what is on hand by item, lot and place, and the
// movements behind it, with the exact quantity of each. Read through the
// bounded pages of the stock reads, a page at a time: a list that is not
// complete says so and offers the next page; a failed read says so and is
// never shown as empty. The server decides who may read; this screen asks
// the same (the entry, the route and the read agree).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/stock_view.dart';
import '../application/stock_walk.dart';
import '../domain/stock_page.dart';
import '../providers/stock_providers.dart';
import 'stock_day.dart';
import 'stock_first_run.dart';
import 'stock_place_text.dart';

class StockScreen extends ConsumerWidget {
  /// The balances (`/stock`) or the movement log (`/stock/movements`): the
  /// route names the page, the control beside the title only moves between them.
  const StockScreen({super.key, this.tab = StockTab.onHand});

  final StockTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final view = ref.watch(stockViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(tab == StockTab.onHand ? l10n.permModuleStock : l10n.stockTabMovements),
        actions: [
          if (workspaceId != null)
            IconButton(
              key: const ValueKey('stock-reload'),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.overviewLayoutReload,
              onPressed: () {
                final filters = _filtersOf(workspaceId, view);
                ref
                  ..invalidate(stockOnHandWalkProvider(filters))
                  ..invalidate(stockMovementsWalkProvider(filters))
                  ..invalidate(stockItemsProvider(workspaceId))
                  ..invalidate(stockPlacesProvider(workspaceId));
              },
            ),
        ],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<StockTab>(
                    key: const ValueKey('stock-tabs'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: StockTab.onHand,
                        label: Text(l10n.stockTabOnHand),
                      ),
                      ButtonSegment(
                        value: StockTab.movements,
                        label: Text(l10n.stockTabMovements),
                      ),
                    ],
                    selected: {tab},
                    onSelectionChanged: (s) =>
                        context.go(s.first == StockTab.movements ? '/stock/movements' : '/stock'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Filters(workspaceId: workspaceId, view: view),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: tab == StockTab.onHand
                        ? _OnHandList(workspaceId: workspaceId, view: view)
                        : _MovementsList(workspaceId: workspaceId, view: view),
                  ),
                ],
              ),
            ),
    );
  }
}

StockFilters _filtersOf(String workspaceId, StockView view) => (
  workspaceId: workspaceId,
  itemId: view.itemId,
  locationId: view.locationId,
);

/// The item and place filters. A filter list that could not be read is
/// simply absent: the lists below still read everything.
class _Filters extends ConsumerWidget {
  const _Filters({required this.workspaceId, required this.view});

  final String workspaceId;
  final StockView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // A filter list that could not be read is absent: the lists below still
    // read everything.
    final items = ref.watch(stockItemsProvider(workspaceId)).value ?? const []; // empty-ok: no item filter is offered
    final places = ref.watch(stockPlacesProvider(workspaceId)).value ?? const []; // empty-ok: no place filter is offered
    final addresses = ref.watch(stockAddressesProvider(workspaceId));
    final notifier = ref.read(stockViewProvider.notifier);
    Widget pick<T>(
      Key key,
      String label,
      String? value,
      List<(String, String)> options,
      void Function(String? id) onChanged,
    ) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: DropdownButtonFormField<String?>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String?>(child: Text(l10n.inboxFilterAll)),
          for (final (id, text) in options)
            DropdownMenuItem<String?>(value: id, child: Text(text)),
        ],
        onChanged: onChanged,
      ),
    );
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        pick<StockItem>(
          const ValueKey('stock-filter-item'),
          l10n.expenseSupplyItem,
          view.itemId,
          [for (final i in items) (i.id, i.name)],
          (id) => notifier.filter(itemId: id, locationId: view.locationId),
        ),
        pick<StockPlace>(
          const ValueKey('stock-filter-place'),
          l10n.calendarDeskColumnPlace,
          view.locationId,
          [for (final p in places) (p.id, addresses[p.id] ?? p.label)],
          (id) => notifier.filter(itemId: view.itemId, locationId: id),
        ),
      ],
    );
  }
}

class _OnHandList extends ConsumerWidget {
  const _OnHandList({required this.workspaceId, required this.view});

  final String workspaceId;
  final StockView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockOnHandWalkProvider(_filtersOf(workspaceId, view));
    final addresses = ref.watch(stockAddressesProvider(workspaceId));
    final walk = ref.watch(provider);
    return _Walk<StockOnHandRow>(
      walk: walk,
      emptyText: view.filtered ? l10n.stockEmptyFiltered : l10n.stockEmpty,
      empty: view.filtered ? null : StockFirstRun(workspaceId: workspaceId),
      onRetry: () => ref.read(provider.notifier).loadMore(first: walk.rows.isEmpty),
      onMore: () => ref.read(provider.notifier).loadMore(),
      tile: (row) => ListTile(
        key: ValueKey('stock-onhand-${row.itemId}-${row.locationId}-${row.lotId}'),
        title: Text(row.itemLabel),
        subtitle: Text(
          '${addresses[row.locationId] ?? row.locationLabel} · '
          '${row.lotCode == null ? l10n.stockNoLot : l10n.stockLotLabel(row.lotCode!)}',
        ),
        trailing: Text(
          l10n.stockQuantityWithUnit(row.quantity.text, row.unit),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // #4434 -- where else the item is, and where it was on a past day
        onTap: () => context.push('/stock/where/${row.itemId}${row.lotId == null ? '' : '?lot=${row.lotId}'}'),
      ),
    );
  }
}

class _MovementsList extends ConsumerWidget {
  const _MovementsList({required this.workspaceId, required this.view});

  final String workspaceId;
  final StockView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = stockMovementsWalkProvider(_filtersOf(workspaceId, view));
    final addresses = ref.watch(stockAddressesProvider(workspaceId));
    final walk = ref.watch(provider);
    final day = MaterialLocalizations.of(context);
    return _Walk<StockMovementRow>(
      walk: walk,
      emptyText: view.filtered ? l10n.stockEmptyFiltered : l10n.stockMovementsEmpty,
      onRetry: () => ref.read(provider.notifier).loadMore(first: walk.rows.isEmpty),
      onMore: () => ref.read(provider.notifier).loadMore(),
      tile: (m) => ListTile(
        key: ValueKey('stock-movement-${m.id}'),
        title: Text(m.itemLabel),
        subtitle: Text(
          '${addresses[m.fromLocationId] ?? m.fromLocationCode} → ${addresses[m.toLocationId] ?? m.toLocationCode} · '
          '${day.formatCompactDate(stockDayOf(ref, m.occurredAt))}',
        ),
        trailing: Text(
          l10n.stockQuantityWithUnit(m.quantity.text, m.unit),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        onTap: () => context.push('/stock/movements/${m.id}'),
      ),
    );
  }
}

/// A walk's rows with its states: loading, failed, empty, rows, and the next
/// page when one follows.
class _Walk<T> extends StatelessWidget {
  const _Walk({
    required this.walk,
    required this.emptyText,
    required this.tile,
    this.empty,
    required this.onRetry,
    required this.onMore,
  });

  final StockWalkState<T> walk;
  final String emptyText;

  /// #4350 -- what an empty list shows instead of [emptyText] (the first-run page).
  final Widget? empty;
  final Widget Function(T row) tile;
  final VoidCallback onRetry;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (walk.isFirstLoad) return const LoadingView();
    if (walk.failedFirst) {
      return Column(
        key: const ValueKey('stock-failed'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.stockReadFailed),
          TextButton(
            key: const ValueKey('stock-retry'),
            onPressed: onRetry,
            child: Text(l10n.identityConnectRetry),
          ),
        ],
      );
    }
    if (walk.rows.isEmpty && walk.complete) {
      return empty ?? Center(key: const ValueKey('stock-empty'), child: Text(emptyText));
    }
    return ListView(
      children: [
        for (final row in walk.rows) tile(row),
        if (walk.error != null)
          Padding(
            key: const ValueKey('stock-more-failed'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Text(l10n.stockReadFailed),
                TextButton(
                  key: const ValueKey('stock-more-retry'),
                  onPressed: onRetry,
                  child: Text(l10n.identityConnectRetry),
                ),
              ],
            ),
          )
        else if (walk.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LoadingView(),
          )
        else if (walk.canLoadMore)
          TextButton(
            key: const ValueKey('stock-more'),
            onPressed: onMore,
            child: Text(l10n.portalDirectoryShowMore),
          ),
      ],
    );
  }
}
