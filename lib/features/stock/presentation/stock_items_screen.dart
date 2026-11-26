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
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/filter_chips.dart';
import '../../../core/ui/kit/kit_metrics.dart';
import '../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../application/stock_walk.dart';
import '../domain/stock_code_resolver.dart';
import '../domain/stock_config.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_item_providers.dart';
import '../providers/stock_providers.dart';
import 'stock_item_add.dart';
import 'stock_item_page.dart';
import 'stock_item_row.dart';
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
          final open = stockItemBesideList(context) ? id : null;
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
            // the list keeps its reading width, beside the item or alone
            list: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
                child: Column(
                  children: [
                    Padding(
                      padding: AppSpacing.mdAll,
                      child: Text(l10n.stockItemsIntro, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(child: _Items(workspaceId: workspaceId, addFirst: addFirst, open: open)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Items extends ConsumerStatefulWidget {
  const _Items({required this.workspaceId, this.addFirst = false, this.open});

  final String workspaceId;
  final bool addFirst;

  /// The item open beside the list, marked in it.
  final String? open;

  @override
  ConsumerState<_Items> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<_Items> {
  final _search = TextEditingController();
  String? _place;
  bool _noHome = false;
  String _query = '';

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
      setState(() => _place = place.id);
    } else if (item != null && item.id.isNotEmpty) {
      openRecord(context, Routes.stockItems, item.id);
    }
  }

  @override
  Widget build(BuildContext context) => ScanScope(
    enabled: StockScreenScan(ref).on,
    onScan: (code) => unawaited(_fromScanner(code)),
    child: _content(context),
  );

  /// Search, the place, and "all" or "without a home place" above the list.
  Widget _filters(BuildContext context, List<StockPlaceConfig> places, String separator) {
    final l10n = context.l10n;
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    return Padding(
      padding: AppSpacing.mdH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mayManage) ...[
            FilledButton.icon(
              key: const ValueKey('stock-item-add'),
              icon: const Icon(Icons.add),
              label: Text(l10n.stockItemAddButton),
              onPressed: () => unawaited(_add()),
            ),
            const FormGap.small(),
          ],
          AppTextField(
            key: const ValueKey('stock-registry-search'),
            controller: _search,
            fieldKey: 'search',
            label: l10n.stockRegistrySearch,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: _submitted,
          ),
          const FormGap.small(),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: KitMetrics.dropdownMaxWidth),
                child: AppDropdownField<String?>(
                  key: const ValueKey('stock-registry-place'),
                  label: l10n.stockRegistryPlaceFilter,
                  value: _place,
                  items: [
                    (null, l10n.stockRegistryAllPlaces),
                    for (final p in [...places.where((p) => !p.virtual)]..sort((a, b) => a.addressPath.compareTo(b.addressPath)))
                      (p.id, p.addressPath.split(stockAddressJoint).join(separator)),
                  ],
                  onChanged: _noHome ? null : (v) => setState(() => _place = v),
                ),
              ),
              FilterChips<bool>(
                key: const ValueKey('stock-registry-home-filter'),
                options: [
                  (value: false, label: l10n.stockItemFilterAll, key: const ValueKey('stock-registry-all')),
                  (value: true, label: l10n.stockItemFilterNoHome, key: const ValueKey('stock-registry-no-home')),
                ],
                selected: _noHome,
                onSelected: (v) => setState(() {
                  _noHome = v;
                  if (v) _place = null;
                }),
              ),
            ],
          ),
          const FormGap.small(),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = context.l10n;
    final separator = ref.watch(stockAddressSeparatorProvider);
    final places = ref.watch(stockPlaceConfigsProvider(widget.workspaceId)).value ?? const <StockPlaceConfig>[]; // empty-ok: the places only feed a filter and a choice
    final low = ref.watch(stockLowKeysProvider(widget.workspaceId));
    final walk = ref.watch(stockRegistryWalkProvider(_filter));
    if (walk.error != null) {
      return Center(
        child: StockReadFailed(
          keyName: 'stock-items',
          error: walk.error!,
          // the page that failed is asked again; the first, when nothing was read
          onRetry: walk.rows.isEmpty ? _reload : () => unawaited(ref.read(stockRegistryWalkProvider(_filter).notifier).loadMore()),
        ),
      );
    }
    final shown = [for (final r in walk.rows) if (_matches(r, separator)) r];
    return Column(
      children: [
        _filters(context, places, separator),
        Expanded(
          child: walk.loading && walk.rows.isEmpty
              ? const LoadingView()
              : shown.isEmpty
              ? EmptyState(key: const ValueKey('stock-items-empty'), icon: Icons.inventory_2_outlined, title: l10n.stockItemsEmpty)
              : ListView(
                  key: const ValueKey('stock-items-list'),
                  children: [
                    for (final r in shown)
                      StockItemRow(
                        row: r,
                        attention: stockAttentionOf(r, low),
                        separator: separator,
                        selected: r.itemId == widget.open,
                        onOpen: () => widget.open == null
                            ? openRecord(context, Routes.stockItems, r.itemId)
                            : moveToRecord(context, Routes.stockItems, r.itemId),
                      ),
                    if (!walk.complete && walk.next != null)
                      TextButton(
                        key: const ValueKey('stock-registry-more'),
                        onPressed: walk.loading
                            ? null
                            : () => unawaited(ref.read(stockRegistryWalkProvider(_filter).notifier).loadMore()),
                        child: Text(l10n.stockRegistryMore),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
