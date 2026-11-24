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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/scan/scan_scope.dart';
import '../../../core/text/collation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_code_resolver.dart';
import '../domain/stock_config.dart';
import '../domain/stock_page.dart';
import '../domain/stock_registry.dart';
import '../domain/stock_tags.dart';
import '../providers/stock_providers.dart';
import 'item_group_assign_dialog.dart';
import 'stock_home_sheet.dart';
import 'stock_item_add.dart';
import 'stock_item_editor.dart';
import 'stock_mapping_editor.dart';
import 'stock_screen_scan.dart';
import 'stock_tags_dialog.dart';
import 'stock_variants_editor.dart';

class StockItemsScreen extends ConsumerWidget {
  const StockItemsScreen({super.key, this.addFirst = false});

  /// #4350 -- the first-run link: the page opens with "Add an item" already asked.
  final bool addFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.stockItemsTitle),
        actions: [HelpDot(l10n.permModuleStock, anchor: HelpAnchor.moneyStockRegistry)],
      ),
      body: workspaceId == null
          ? const LoadingView()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(l10n.stockItemsIntro, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    Expanded(child: _Items(workspaceId: workspaceId, addFirst: addFirst)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Items extends ConsumerStatefulWidget {
  const _Items({required this.workspaceId, this.addFirst = false});

  final String workspaceId;
  final bool addFirst;

  @override
  ConsumerState<_Items> createState() => _ItemsState();
}

class _ItemsState extends ConsumerState<_Items> {
  final _search = TextEditingController();
  final _rows = <StockRegistryRow>[];
  StockCursor? _next;
  bool _loading = true;
  bool _failed = false;
  String? _place;
  bool _noHome = false;
  String _query = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
    if (widget.addFirst) WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_add()));
  }

  /// Chooses a service to keep in stock; the list is read again when an item was made.
  Future<void> _add() async {
    if (!mounted) return;
    if (await StockItemAdd(ref).run(context, widget.workspaceId)) unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _rows.clear();
        _next = null;
      }
    });
    try {
      final page = await ref.read(stockRegistryProvider).page(
        widget.workspaceId,
        placeId: _place,
        noHome: _noHome,
        after: reset ? null : _next,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows.addAll(page.rows);
        _next = page.complete ? null : page.next;
        _loading = false;
      });
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'the registry was not read', error: e, stackTrace: st);
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  bool _matches(StockRegistryRow r, String separator) {
    final q = foldForSearch(_query.trim());
    if (q.isEmpty) return true;
    return foldForSearch(r.label).contains(q) ||
        foldForSearch(r.barcode ?? '').contains(q) ||
        foldForSearch((r.homeAddressPath ?? '').split(stockAddressJoint).join(separator)).contains(q);
  }

  /// A search submitted that is a whole barcode, or shows nothing, is a code typed by hand: it goes the way a scanner's goes.
  void _submitted(String text, bool mayManage) {
    final code = text.trim();
    if (code.isEmpty) return;
    final separator = ref.read(stockAddressSeparatorProvider);
    final shown = _rows.where((r) => _matches(r, separator)).toList();
    // A list that still shows rows is a search by name or address; only a whole barcode among them, or nothing shown at
    // all, is a code typed by hand.
    if (shown.isNotEmpty && !shown.any((r) => r.barcode == code)) return;
    unawaited(_fromScanner(code, mayManage));
  }

  /// A scanner's code (#4359): an item opens, a place filters the list by it.
  Future<void> _fromScanner(String code, bool mayManage) async {
    final answer = await StockScreenScan(ref).resolve(context, widget.workspaceId, code);
    if (answer == null || !mounted) return;
    final item = answer.item;
    final place = answer.place;
    if (answer.kind == ScannedKind.place && place != null && !_noHome) {
      _place = place.id;
      await _load(reset: true);
    } else if (item != null && item.id.isNotEmpty && mayManage) {
      final lotsOn = ref.read(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockLots);
      await showStockItemEditor(
        context,
        ref.read(stockConfigCommandsProvider),
        workspaceId: widget.workspaceId,
        itemId: item.id,
        itemName: item.name,
        options: (lots: lotsOn, keep: false, groups: itemGroupsIfOn(ref)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    return ScanScope(
      enabled: StockScreenScan(ref).on,
      onScan: (code) => unawaited(_fromScanner(code, mayManage)),
      child: _content(context, mayManage),
    );
  }

  Widget _content(BuildContext context, bool mayManage) {
    final l10n = context.l10n;
    final separator = ref.watch(stockAddressSeparatorProvider);
    final places = ref.watch(stockPlaceConfigsProvider(widget.workspaceId)).value ?? const <StockPlaceConfig>[]; // empty-ok: the places only feed a filter and a choice
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.stockReadFailed, key: const ValueKey('stock-items-failed')),
            const FormGap(),
            OutlinedButton(
              key: const ValueKey('stock-items-retry'),
              onPressed: () => unawaited(_load(reset: true)),
              child: Text(l10n.identityConnectRetry),
            ),
          ],
        ),
      );
    }
    final shown = [for (final r in _rows) if (_matches(r, separator)) r];
    final seen = <String>{};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              if (mayManage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('stock-item-add'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.stockItemAddButton),
                    onPressed: () => unawaited(_add()),
                  ),
                ),
              const FormGap.small(),
              AppTextField(
                key: const ValueKey('stock-registry-search'),
                controller: _search,
                fieldKey: 'search',
                label: l10n.stockRegistrySearch,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) => _submitted(v, mayManage),
              ),
              const FormGap.small(),
              AppDropdownField<String?>(
                key: const ValueKey('stock-registry-place'),
                label: l10n.stockRegistryPlaceFilter,
                value: _place,
                items: [
                  (null, l10n.stockRegistryAllPlaces),
                  for (final p in [...places.where((p) => !p.virtual)]..sort((a, b) => a.addressPath.compareTo(b.addressPath)))
                    (p.id, p.addressPath.split(stockAddressJoint).join(separator)),
                ],
                onChanged: _noHome
                    ? null
                    : (v) {
                        _place = v;
                        unawaited(_load(reset: true));
                      },
              ),
              SwitchListTile(
                key: const ValueKey('stock-registry-no-home'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.stockRegistryNoHomeFilter),
                value: _noHome,
                onChanged: (v) {
                  _noHome = v;
                  if (v) _place = null;
                  unawaited(_load(reset: true));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _rows.isEmpty
              ? const LoadingView()
              : shown.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(l10n.stockItemsEmpty, key: const ValueKey('stock-items-empty'), textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  children: [
                    for (final r in shown)
                      _RegistryRow(
                        workspaceId: widget.workspaceId,
                        row: r,
                        // the item's own tools sit on its first row only
                        showTools: seen.add(r.itemId),
                        places: places,
                        separator: separator,
                        onHomeChanged: () => _load(reset: true),
                      ),
                    if (_next != null)
                      TextButton(
                        key: const ValueKey('stock-registry-more'),
                        onPressed: _loading ? null : () => unawaited(_load(reset: false)),
                        child: Text(l10n.stockRegistryMore),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RegistryRow extends ConsumerWidget {
  const _RegistryRow({
    required this.workspaceId,
    required this.row,
    required this.showTools,
    required this.places,
    required this.separator,
    required this.onHomeChanged,
  });

  final String workspaceId;
  final StockRegistryRow row;
  final bool showTools;
  final List<StockPlaceConfig> places;
  final String separator;
  final VoidCallback onHomeChanged;

  String _details(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final cost = !row.costVisible
        ? l10n.stockRegistryCostHidden
        : row.costMinor == null
        ? l10n.stockRegistryCostUnknown
        : l10n.stockRegistryCost(format.money(row.costMinor!));
    return [
      if (row.barcode != null) row.barcode!,
      if (row.unit.isNotEmpty) row.unit,
      if (row.priceCents != null) l10n.stockRegistryPrice(format.money(row.priceCents!)),
      cost,
      if (row.homeAddressPath == null) l10n.stockRegistryNoHome,
      if (row.homeAddressPath != null)
        l10n.stockRegistryHome(row.homeAddressPath!.split(stockAddressJoint).join(separator)),
      l10n.stockRegistryOnHand(l10n.stockQuantityWithUnit(row.onHand.text, row.unit)),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // #4169: the editors are for a person who may manage the stock; the server asks the same.
    final mayManage = ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
    final lotsOn = ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockLots);
    return ListTile(
      key: ValueKey('stock-item-${row.key}'),
      title: Text(row.label),
      subtitle: Text(_details(context)),
      trailing: !mayManage
          ? null
          : Wrap(
              children: [
                IconButton(
                  key: ValueKey('stock-home-${row.key}'),
                  icon: const Icon(Icons.place_outlined),
                  tooltip: l10n.stockRegistryHomePlace,
                  onPressed: () async {
                    final saved = await showStockHomeSheet(
                      context,
                      ref.read(stockRegistryProvider),
                      workspaceId: workspaceId,
                      row: row,
                      places: places,
                      separator: separator,
                    );
                    if (saved) onHomeChanged();
                  },
                ),
                if (ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockItemGroups))
                  IconButton(
                    key: ValueKey('stock-item-group-${row.itemId}'),
                    icon: const Icon(Icons.folder_copy_outlined),
                    tooltip: l10n.itemGroupAssignOpen,
                    onPressed: () => showItemGroupAssign(context, workspaceId: workspaceId, itemId: row.itemId, itemName: row.itemName),
                  ),
                if (ref.watch(stockTagsProvider))
                  IconButton(
                    key: ValueKey('stock-tags-${row.itemId}'),
                    icon: const Icon(Icons.nfc),
                    tooltip: l10n.stockTagsOpen,
                    onPressed: () => showStockTagsDialog(
                      context,
                      workspaceId: workspaceId,
                      owner: TagOwner.item(row.itemId),
                      name: row.itemName,
                    ),
                  ),
                if (showTools) ...[
                  IconButton(
                    key: ValueKey('stock-edit-item-${row.itemId}'),
                    icon: const Icon(Icons.tune),
                    tooltip: l10n.stockEditItem,
                    onPressed: () => showStockItemEditor(
                      context,
                      ref.read(stockConfigCommandsProvider),
                      workspaceId: workspaceId,
                      itemId: row.itemId,
                      itemName: row.itemName,
                      options: (lots: lotsOn, keep: false, groups: itemGroupsIfOn(ref)),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('stock-edit-variants-${row.itemId}'),
                    icon: const Icon(Icons.style_outlined),
                    tooltip: l10n.stockVariantsEdit,
                    onPressed: () => showStockVariantsEditor(
                      context,
                      ref.read(stockConfigCommandsProvider),
                      workspaceId: workspaceId,
                      itemId: row.itemId,
                      itemName: row.itemName,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('stock-edit-mappings-${row.itemId}'),
                    icon: const Icon(Icons.link),
                    tooltip: l10n.stockMappingsEdit,
                    onPressed: () => showStockMappings(
                      context,
                      ref.read(stockConfigCommandsProvider),
                      workspaceId: workspaceId,
                      itemId: row.itemId,
                      itemName: row.itemName,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
