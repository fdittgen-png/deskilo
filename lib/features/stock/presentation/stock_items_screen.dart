// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4299 -- Items: the item registry of the stock, on a page of its own
// (`/stock/items`). Each item opens its settings, its variants and its supplier
// articles; a person who may only look sees the list and no editor. A list that
// could not be read says so: it is never shown as "no items".
// #4293 -- and it is the product and place registry: per item (per variant) the barcode, unit,
// retail price, last known cost (or "cost not shown"), home address and what is on hand, filtered
// by a place or by "no home place", read in bounded pages. A barcode typed or scanned into the
// search opens its item.
// #4480 -- a row reads at a glance (the name, one line of facts, a badge for what the item needs) and opens the
// item at its own address, `/stock/items/<id>`: beside the list from the expanded window class, a page of its own
// below it. The item's editors are reached from its page, one worded action per section; "no home place" is a chip.
// #4483 -- laid out per form factor. On a phone (compact, medium) each item is a card whose chips open its editors;
// at the desk (expanded and wider) the items are a grid at the page's measure, one row selected at a time, with a
// toolbar above it that holds the filters and acts on the selected row. The selection, the sort and the rows last
// read are the page's: a save that reads the list again keeps the row selected and shows its new values.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/navigation/list_detail_route.dart';
import '../../../core/navigation/routes.dart';
import '../../../core/scan/scan_scope.dart';
import '../../../core/storage/pane_width_store.dart';
import '../../../core/text/collation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/adaptive/page_measures.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../core/ui/kit/records_table_model.dart';
import '../../../core/ui/loading_view.dart';
import '../../money/domain/service_item.dart';
import '../../money/providers/money_providers.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/stock_walk.dart';
import '../domain/stock_code_resolver.dart';
import '../domain/stock_config.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_item_providers.dart';
import '../providers/stock_providers.dart';
import 'stock_item_actions.dart';
import 'stock_item_add.dart';
import 'stock_item_card.dart';
import 'stock_item_page.dart';
import 'stock_items_grid.dart';
import 'stock_items_toolbar.dart';
import 'stock_page_shell.dart';
import 'stock_read_failed.dart';
import 'stock_screen_scan.dart';

class StockItemsScreen extends ConsumerWidget {
  const StockItemsScreen({super.key, this.addFirst = false});

  /// #4350 -- the first-run link: the page opens with "Add an item" already asked.
  final bool addFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return StockPageShell(
      title: l10n.stockItemsTitle,
      anchor: HelpAnchor.moneyStockRegistry,
      helpTopic: l10n.permModuleStock,
      body: (context, ref, workspaceId) => OpenRecord(
        listPath: Routes.stockItems,
        builder: (context, id) {
          final desk = stockItemBesideList(context);
          final open = desk ? id : null;
          final items = _Items(workspaceId: workspaceId, addFirst: addFirst, open: open, desk: desk);
          return ListDetailScaffold(
            id: 'stock-items',
            paneStore: ref.watch(paneWidthStoreProvider),
            selected: open,
            onClose: () => closeRecord(context, Routes.stockItems),
            detail: (context, id) => StockItemPage(
              key: ValueKey('stock-item-panel-$id'),
              itemId: id,
              onClose: () => closeRecord(context, Routes.stockItems),
            ),
            // At the desk the grid takes the page's measure; on a phone the cards keep the reading width.
            list: desk
                ? items
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
                      child: items,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _Items extends ConsumerStatefulWidget {
  const _Items({required this.workspaceId, required this.desk, this.addFirst = false, this.open});

  final String workspaceId;
  final bool addFirst;

  /// The grid with its toolbar (the desk), else the cards (a phone).
  final bool desk;

  /// The item open beside the grid.
  final String? open;

  @override
  ConsumerState<_Items> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<_Items> {
  final _search = TextEditingController();
  String? _place;
  bool _noHome = false;
  String _query = '';

  /// The selected row of the grid (its `StockRegistryRow.key`).
  String? _selected;

  /// The grid's sort: the registry's own order (by name) until a heading is clicked.
  RecordsQuery _sort = const RecordsQuery();

  /// The rows last read under the filters: shown while a save reads them again, so the list does not blink.
  List<StockRegistryRow> _kept = const [];

  /// #4401 -- the registry under the filters chosen, read by the one stock walk: a filter changed is another walk.
  ({String workspaceId, String? placeId, bool noHome}) get _filter => (workspaceId: widget.workspaceId, placeId: _place, noHome: _noHome);

  StockWalkState<StockRegistryRow> get _walk => ref.read(stockRegistryWalkProvider(_filter));

  /// Reads the registry again from its first page.
  void _reload() => unawaited(ref.read(stockRegistryWalkProvider(_filter).notifier).reload());

  @override
  void initState() {
    super.initState();
    if (widget.addFirst) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_add()));
  }

  /// Chooses a service to keep in stock; the list is read again when an item was made.
  Future<void> _add() async {
    if (!mounted) return;
    if (await StockItemAdd(ref).run(context, widget.workspaceId)) _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(StockRegistryRow r, String separator) {
    final q = foldForSearch(_query.trim());
    if (q.isEmpty) return true;
    return foldForSearch(r.label).contains(q) ||
        foldForSearch(r.barcode ?? '').contains(q) ||
        foldForSearch((r.homeAddressPath ?? '').split(stockAddressJoint).join(separator)).contains(q);
  }

  /// A search submitted that is a whole barcode, or shows nothing, is a code typed by hand: it goes the way a scanner's goes.
  void _submitted(String text) {
    final code = text.trim();
    if (code.isEmpty) return;
    final separator = ref.read(stockAddressSeparatorProvider);
    final shown = _walk.rows.where((r) => _matches(r, separator)).toList();
    // A list that still shows rows is a search by name or address; only a whole barcode among them, or nothing shown at
    // all, is a code typed by hand.
    if (shown.isNotEmpty && !shown.any((r) => r.barcode == code)) return;
    unawaited(_fromScanner(code));
  }

  /// A scanner's code (#4359): an item opens its page (#4480), a place filters the list by it.
  Future<void> _fromScanner(String code) async {
    final answer = await StockScreenScan(ref).resolve(context, widget.workspaceId, code);
    if (answer == null || !mounted) return;
    final item = answer.item;
    final place = answer.place;
    if (answer.kind == ScannedKind.place && place != null && !_noHome) {
      _setFilter(() => _place = place.id);
    } else if (item != null && item.id.isNotEmpty) {
      openRecord(context, Routes.stockItems, item.id);
    }
  }

  /// Another filter is another list: the rows kept from the last one are not shown under it.
  void _setFilter(VoidCallback change) => setState(() {
    change();
    _kept = const [];
  });

  /// The grid's selection is [key]: a click, the arrows, an item opened, or none.
  void _choose(String? key) => setState(() => _selected = key);

  /// A click on a row selects it; with an item open beside the grid, the item follows the selection.
  void _select(StockRegistryRow row) {
    _choose(row.key);
    final open = widget.open;
    if (open != null && open != row.itemId) moveToRecord(context, Routes.stockItems, row.itemId);
  }

  /// Opens the item of [row] (beside the grid at the desk, a page of its own on a phone).
  void _open(StockRegistryRow row) {
    if (widget.desk) _choose(row.key);
    widget.open == null
        ? openRecord(context, Routes.stockItems, row.itemId)
        : moveToRecord(context, Routes.stockItems, row.itemId);
  }

  void _clear() {
    _choose(null);
    if (widget.open != null) closeRecord(context, Routes.stockItems);
  }

  void _sortBy(String column) => setState(
    () => _sort = _sort.sortColumn == column
        ? _sort.copyWith(ascending: !_sort.ascending)
        : RecordsQuery(sortColumn: column),
  );

  void _loadMore() => unawaited(ref.read(stockRegistryWalkProvider(_filter).notifier).loadMore());

  @override
  Widget build(BuildContext context) => ScanScope(
    enabled: StockScreenScan(ref).on,
    onScan: (code) => unawaited(_fromScanner(code)),
    child: _content(context),
  );

  Widget _filters(List<StockPlaceConfig> places, String separator) => StockItemsFilters(
    key: const ValueKey('stock-items-filters'),
    search: _search,
    places: places,
    separator: separator,
    place: _place,
    noHome: _noHome,
    wide: widget.desk,
    onQuery: (v) => setState(() => _query = v),
    onSubmitted: _submitted,
    onPlace: (v) => _setFilter(() => _place = v),
    onNoHome: (v) => _setFilter(() {
      _noHome = v;
      if (v) _place = null;
    }),
  );

  /// The rows to show: those read under the filters, or while a save reads them again the rows read before.
  List<StockRegistryRow> _rows(StockWalkState<StockRegistryRow> walk) {
    final rows = walk.rows.isEmpty && walk.loading ? _kept : walk.rows;
    if (!walk.loading || walk.rows.isNotEmpty) _kept = walk.rows;
    return rows;
  }

  /// The selected row among [shown]; an item opened by its address (a scan, a link) is the grid's selection.
  StockRegistryRow? _selectedOf(List<StockRegistryRow> shown) {
    final open = widget.open;
    final selected = shown.where((r) => r.key == _selected).firstOrNull;
    if (open == null || selected?.itemId == open) return selected;
    final opened = shown.where((r) => r.itemId == open).firstOrNull ?? selected;
    _selected = opened?.key;
    return opened;
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final separator = ref.watch(stockAddressSeparatorProvider);
    final places = ref.watch(stockPlaceConfigsProvider(widget.workspaceId)).value ?? const <StockPlaceConfig>[]; // empty-ok: the places only feed a filter and a choice
    final services = ref.watch(allServicesProvider).value ?? const <ServiceItem>[]; // empty-ok: no Edit of name, price and VAT then
    final mayAdd = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final acts = StockItemActions(context, ref, workspaceId: widget.workspaceId, services: services);
    final walk = ref.watch(stockRegistryWalkProvider(_filter));
    if (walk.error != null) {
      return Center(
        child: StockReadFailed(
          keyName: 'stock-items',
          error: walk.error!,
          // the page that failed is asked again; the first, when nothing was read
          onRetry: walk.rows.isEmpty ? _reload : _loadMore,
        ),
      );
    }
    final rows = _rows(walk);
    final shown = [for (final r in rows) if (_matches(r, separator)) r];
    final selected = _selectedOf(shown);
    final more = !walk.complete && walk.next != null
        ? TextButton(
            key: const ValueKey('stock-registry-more'),
            onPressed: walk.loading ? null : _loadMore,
            child: Text(l10n.stockRegistryMore),
          )
        : null;
    final actionsOf = acts.offer();
    final list = rows.isEmpty && walk.loading
        ? const LoadingView()
        : shown.isEmpty
        ? EmptyState(key: const ValueKey('stock-items-empty'), icon: Icons.inventory_2_outlined, title: l10n.stockItemsEmpty)
        : widget.desk
        ? StockItemsGrid(
            workspaceId: widget.workspaceId,
            rows: shown,
            separator: separator,
            selected: selected?.key,
            sort: _sort,
            onSort: _sortBy,
            onSelect: _select,
            onOpen: _open,
          )
        : _cards(shown, separator, actionsOf, more);
    final intro = Padding(
      padding: AppSpacing.mdAll,
      child: Text(l10n.stockItemsIntro, style: Theme.of(context).textTheme.bodyMedium),
    );
    final add = mayAdd ? () => unawaited(_add()) : null;
    if (!widget.desk) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          intro,
          Padding(
            padding: AppSpacing.mdH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (add != null) ...[
                  FilledButton.icon(
                    key: const ValueKey('stock-item-add'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.stockItemAddButton),
                    onPressed: add,
                  ),
                  const FormGap.small(),
                ],
                _filters(places, separator),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        Padding(
          padding: AppSpacing.mdH,
          child: StockItemsToolbar(
            filters: _filters(places, separator),
            selected: selected == null ? null : acts.nameOf(selected),
            actions: selected == null ? const [] : actionsOf(selected),
            onOpen: () => _open(selected!),
            onClear: _clear,
            onAdd: add,
          ),
        ),
        const FormGap.small(),
        Expanded(child: list),
        ?more,
      ],
    );
  }

  /// The phone's cards, with "Show more" after the last while the registry has more.
  Widget _cards(
    List<StockRegistryRow> shown,
    String separator,
    List<StockItemAction> Function(StockRegistryRow row) actionsOf,
    Widget? more,
  ) {
    final low = ref.watch(stockLowKeysProvider(widget.workspaceId));
    return ListView.separated(
      key: const ValueKey('stock-items-list'),
      padding: AppSpacing.mdAll,
      itemCount: shown.length + (more == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        if (i == shown.length) return more!;
        final r = shown[i];
        return StockItemCard(
          row: r,
          attention: stockAttentionOf(r, low),
          separator: separator,
          actions: actionsOf(r),
          onOpen: () => _open(r),
        );
      },
    );
  }
}
