// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4483 -- the items of the stock at the desk (the expanded window class and wider): a grid of one dense row per
// item or variant (the name, its price, what is on hand, its home place, its group where the business keeps groups,
// and what it needs), sorted by a click on the name, price or on-hand heading. A click selects one row (highlighted,
// a check mark in its first cell) and gives the grid the keyboard: the arrows move the selection, Enter opens the
// selected item, as a double click does. The selection is the page's, so it survives a save that reads the list
// again. The columns, their widths and the heading are the kit's records table's.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/text/collation.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/adaptive/window_class.dart';
import '../../../core/ui/kit/list_detail_open.dart';
import '../../../core/ui/kit/records_table_cells.dart';
import '../../../core/ui/kit/records_table_model.dart';
import '../../../core/ui/kit/records_table_parts.dart';
import '../../../core/ui/kit/records_table_reveal.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../../../core/ui/mouse_presence.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import '../providers/stock_item_providers.dart';
import 'stock_item_card.dart';
import 'stock_item_view.dart';

/// [rows] in the order [sort] asks for, by the sort key of its column among [columns]; equal keys keep their order.
List<StockRegistryRow> _sortRows(
  List<StockRegistryRow> rows,
  List<RecordColumn<StockRegistryRow>> columns,
  RecordsQuery sort,
) {
  final key = columns
      .where((c) => c.id == sort.sortColumn)
      .firstOrNull
      ?.sortKey;
  if (key == null) return rows;
  final indexed = [for (final (i, r) in rows.indexed) (i, r)]
    ..sort((a, b) {
      final c = key(a.$2).compareTo(key(b.$2));
      final order = sort.ascending ? c : -c;
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, r) in indexed) r];
}

/// The grid of [rows] (the items the filters keep), with the row [selected] (its `StockRegistryRow.key`).
class StockItemsGrid extends ConsumerStatefulWidget {
  const StockItemsGrid({
    super.key,
    required this.workspaceId,
    required this.rows,
    required this.separator,
    required this.selected,
    required this.sort,
    required this.onSort,
    required this.onSelect,
    required this.onOpen,
  });

  final String workspaceId;
  final List<StockRegistryRow> rows;

  /// The business's address separator, for the home place.
  final String separator;
  final String? selected;

  /// The column the rows are sorted by and its direction.
  final RecordsQuery sort;
  final ValueChanged<String> onSort;
  final ValueChanged<StockRegistryRow> onSelect;

  /// Opens the item of the row beside the grid.
  final ValueChanged<StockRegistryRow> onOpen;

  @override
  ConsumerState<StockItemsGrid> createState() => _StockItemsGridState();
}

class _StockItemsGridState extends ConsumerState<StockItemsGrid> {
  final _focus = FocusNode(debugLabel: 'stock items grid');
  final _scroll = ScrollController();
  late final _reveal = RowReveal(_scroll, () => mounted);

  /// A finger's row height until a mouse is connected or used.
  bool _touch = !MousePresence.connected;

  /// The last click: a second one on the same row soon after opens it.
  final _sinceClick = Stopwatch();
  String? _clicked;

  /// The rows as shown, in their order: what the arrows walk.
  List<StockRegistryRow> _shown = const [];

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  double get _rowHeight => _touch ? kMinInteractiveDimension : recordRowHeight;

  void _click(StockRegistryRow row) {
    _focus.requestFocus();
    final twice =
        _clicked == row.key &&
        _sinceClick.isRunning &&
        _sinceClick.elapsed <= kDoubleTapTimeout;
    _clicked = row.key;
    _sinceClick
      ..reset()
      ..start();
    if (twice) {
      widget.onOpen(row);
    } else {
      widget.onSelect(row);
    }
  }

  /// Moves the selection [by] rows (the first row when none is selected) and keeps it in view.
  void _move(int by) {
    if (_shown.isEmpty) return;
    final at = _shown.indexWhere((r) => r.key == widget.selected);
    final to = at < 0 ? 0 : (at + by).clamp(0, _shown.length - 1);
    final row = _shown[to];
    widget.onSelect(row);
    _reveal.reveal(row.key, to, _rowHeight, down: by > 0);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final row = _shown.where((r) => r.key == widget.selected).firstOrNull;
      if (row == null) return KeyEventResult.ignored;
      widget.onOpen(row);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  List<RecordColumn<StockRegistryRow>> _columns(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final scheme = Theme.of(context).colorScheme;
    final groupsOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.stockItemGroups);
    final low = ref.watch(stockLowKeysProvider(widget.workspaceId));
    return [
      RecordColumn(
        id: 'name',
        label: l10n.stockItemNewName,
        flex: 3,
        hideable: false,
        sortKey: (r) => foldForSearch(r.label),
        cell: (context, r) => Row(
          spacing: AppSpacing.sm,
          children: [
            // The mark's room is kept on every row, so the names stand in one column.
            Icon(
              Icons.check,
              key: r.key == widget.selected
                  ? ValueKey('stock-item-check-${r.key}')
                  : null,
              color: r.key == widget.selected
                  ? scheme.primary
                  : Colors.transparent,
              size: AppSpacing.lg,
            ),
            Expanded(
              child: Text(
                r.label,
                key: ValueKey('stock-item-name-${r.key}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      RecordColumn(
        id: 'price',
        label: l10n.servicesPrice,
        numeric: true,
        staysBeside: false,
        sortKey: (r) => r.priceCents ?? -1,
        cell: (context, r) =>
            Text(r.priceCents == null ? '' : format.money(r.priceCents!)),
      ),
      RecordColumn(
        id: 'onHand',
        label: l10n.stockTabOnHand,
        numeric: true,
        sortKey: (r) => r.onHand,
        cell: (context, r) => Text(stockItemOnHand(context, r)),
      ),
      RecordColumn(
        id: 'home',
        label: l10n.stockRegistryHomePlace,
        flex: 2,
        staysBeside: false,
        shownFrom: WindowClass.medium,
        cell: (context, r) => Text(
          stockItemHome(context, r, widget.separator),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (groupsOn)
        RecordColumn(
          id: 'group',
          label: l10n.documentsColGroup,
          staysBeside: false,
          shownFrom: WindowClass.large,
          cell: (context, r) =>
              _GroupCell(workspaceId: widget.workspaceId, itemId: r.itemId),
        ),
      RecordColumn(
        id: 'status',
        label: l10n.membersColStatus,
        flex: 2,
        staysBeside: false,
        shownFrom: WindowClass.expanded,
        cell: (context, r) => switch (stockAttentionOf(r, low).firstOrNull) {
          final first? => StatusChip(
            key: ValueKey('stock-item-badge-${r.key}'),
            label: stockAttentionText(l10n, first),
            tone: StatusTone.warn,
          ),
          null => const SizedBox.shrink(),
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _columns(context);
    _shown = _sortRows(widget.rows, all, widget.sort);
    final shown = _shown;
    return Listener(
      // Rows follow the pointer, as in the kit's tables: short with a mouse, a finger's height touched.
      onPointerDown: (e) {
        final touch = e.kind == PointerDeviceKind.touch;
        if (touch != _touch) setState(() => _touch = touch);
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final (:columns, :mins) = fitRecordColumns(
            context,
            columnsShown(
              all,
              const {},
              beside: ListDetailOpen.of(context),
              room: WindowClass.ofWidth(box.maxWidth),
            ),
            box.maxWidth - 2 * AppSpacing.md,
          );
          return Focus(
            key: const ValueKey('stock-items-grid'),
            focusNode: _focus,
            onKeyEvent: _key,
            onFocusChange: (_) => setState(() {}),
            child: Column(
              children: [
                RecordsHeader<StockRegistryRow>(
                  columns: columns,
                  query: widget.sort,
                  onSort: widget.onSort,
                  shown: shown.length,
                  selectedShown: 0,
                  onSelectShown: (_) {},
                  selectable: false,
                  actionsWidth: 0,
                  dense: !_touch,
                  mins: mins,
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('stock-items-grid-rows'),
                    controller: _scroll,
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = shown[i];
                      return KeyedSubtree(
                        key: _reveal.keyOf(r.key),
                        child: _GridRow(
                          key: ValueKey('stock-item-${r.key}'),
                          rowKey: r.key,
                          cells: recordCells(
                            columns,
                            [for (final c in columns) c.cell(context, r)],
                            mins: mins,
                            lineHeight: _rowHeight,
                          ),
                          selected: r.key == widget.selected,
                          focused: _focus.hasFocus,
                          minHeight: _rowHeight,
                          onTap: () => _click(r),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One row of the grid: highlighted when [selected], ringed while the grid has the keyboard.
class _GridRow extends StatelessWidget {
  const _GridRow({
    super.key,
    required this.rowKey,
    required this.cells,
    required this.selected,
    required this.focused,
    required this.minHeight,
    required this.onTap,
  });

  /// The row's `StockRegistryRow.key`.
  final String rowKey;
  final Widget cells;
  final bool selected;
  final bool focused;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        child: InkWell(
          key: ValueKey('stock-item-select-$rowKey'),
          // The grid is one stop of the keyboard: the arrows walk its rows.
          canRequestFocus: false,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: selected && focused
                  ? Border.all(color: scheme.primary, width: 2)
                  : null,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(padding: AppSpacing.mdH, child: cells),
            ),
          ),
        ),
      ),
    );
  }
}

/// The group the item is in, read when its row is shown; a failed read is said, never shown as no group.
class _GroupCell extends ConsumerWidget {
  const _GroupCell({required this.workspaceId, required this.itemId});

  final String workspaceId;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(
      stockItemGroupNameProvider((workspaceId: workspaceId, itemId: itemId)),
    )) {
      AsyncValue(hasValue: true, :final value) => Text(
        value ?? l10n.stockItemNoGroup,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      AsyncValue(hasError: true) => Tooltip(
        message: l10n.recordsFailed,
        child: Icon(Icons.error_outline, semanticLabel: l10n.recordsFailed),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
