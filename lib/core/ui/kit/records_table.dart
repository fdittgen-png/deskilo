// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 (desk K1) — the records table: sort by a click on a header, filter
// by typing (/ goes to the filter), chips with their counts, a footer with
// the count and one total per currency of what it adds up, selection by
// ticks with a bar that names the action and the number, the keyboard
// (↑ ↓ move, Enter opens, Space ticks, Ctrl/⌘+A selects what is shown), one
// declared list of actions per row, rows 36 high with a mouse and 48 with
// touch, the loading, empty, failed and partly-read states, a header that
// stays, the column choice kept on the device, and cards on a phone.
//
// The rules (query, selection, totals) are records_table_model.dart; the
// drawn parts are records_table_parts.dart.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/context_l10n.dart';
import '../../storage/prefs_stores.dart';
import '../../theme/app_spacing.dart';
import '../adaptive/window_class.dart';
import 'records_table_model.dart';
import 'records_table_parts.dart';

export 'records_table_model.dart';

/// Where the table's rows stand.
enum RecordsState { loading, failed, ready }

/// A desk table of records, cards on a phone.
class RecordsTable<T> extends StatefulWidget {
  const RecordsTable({
    required this.tableId,
    required this.rows,
    required this.keyOf,
    required this.columns,
    required this.searchText,
    required this.onOpen,
    required this.cardBuilder,
    required this.empty,
    this.state = RecordsState.ready,
    this.onRetry,
    this.complete = true,
    this.chips = const [],
    this.amountOf,
    this.formatAmount,
    this.rowActions,
    this.bulkActions = const [],
    this.columnStore,
    this.initialQuery = const RecordsQuery(),
    this.onShown,
    super.key,
  });

  /// #3614 — told the keys of the rows shown, in their order, each time
  /// they are drawn: a record beside the table moves along them.
  final ValueChanged<List<String>>? onShown;

  /// The query the table opens with (its default sort).
  final RecordsQuery initialQuery;

  /// Names the table, for the column choice kept on the device.
  final String tableId;
  final List<T> rows;

  /// A stable key: qualified by source and workspace where rows come from
  /// several of them.
  final String Function(T row) keyOf;
  final List<RecordColumn<T>> columns;
  final String Function(T row) searchText;
  final void Function(T row) onOpen;

  /// A row as a card, on a phone: the same data.
  final Widget Function(BuildContext context, T row) cardBuilder;

  /// What an empty table says: one sentence and one action.
  final Widget empty;
  final RecordsState state;
  final VoidCallback? onRetry;

  /// Whether every row the table could show is loaded.
  final bool complete;
  final List<RecordChip<T>> chips;

  /// What a row adds to the totals, in its own currency.
  final RecordAmount? Function(T row)? amountOf;
  final String Function(String currency, int minor)? formatAmount;
  final List<RecordAction<T>> Function(T row)? rowActions;
  final List<RecordBulkAction> bulkActions;

  /// Where the hidden columns are kept; by default the device's preferences.
  final PrefsStringStore? columnStore;

  @override
  State<RecordsTable<T>> createState() => _RecordsTableState<T>();
}

class _RecordsTableState<T> extends State<RecordsTable<T>> {
  late final _c = RecordsController<T>(
    query: widget.initialQuery,
    keyOf: widget.keyOf,
    searchText: widget.searchText,
    chips: widget.chips,
    columns: widget.columns,
  )..rowsChanged(widget.rows, chips: widget.chips, columns: widget.columns);
  bool _touch = false;
  final _filter = TextEditingController();
  final _filterFocus = FocusNode();
  final _rowsFocus = FocusNode();

  PrefsStringStore get _store =>
      widget.columnStore ??
      PrefsStringStore('records_columns_${widget.tableId}');

  bool get _selectable => widget.bulkActions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(
      _store.read().then(
        (v) {
          if (!mounted || v == null || v.isEmpty) return;
          _c.restoreHidden(v.split(',').toSet());
        },
        // The column choice is a convenience: the table shows every column
        // when it cannot be read, and says why in the log.
        onError: (Object e, StackTrace s) => FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: s,
            library: 'records table',
            context: ErrorDescription('reading the hidden columns'),
          ),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(RecordsTable<T> old) {
    super.didUpdateWidget(old);
    // New rows, chips or columns: the selection follows what is shown.
    if (!identical(old.rows, widget.rows) ||
        !identical(old.chips, widget.chips) ||
        !identical(old.columns, widget.columns)) {
      _c.rowsChanged(widget.rows, chips: widget.chips, columns: widget.columns);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _filter.dispose();
    _filterFocus.dispose();
    _rowsFocus.dispose();
    super.dispose();
  }

  List<RecordColumn<T>> get _columns => [
    for (final c in widget.columns)
      if (!c.hideable || !_c.hidden.contains(c.id)) c,
  ];

  void _toggleColumn(String id) {
    _c.toggleColumn(id);
    final hidden = _c.hidden;
    _store.write(hidden.isEmpty ? null : hidden.join(',')).ignore();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.state) {
      case RecordsState.loading:
        return const Center(child: CircularProgressIndicator());
      case RecordsState.failed:
        return _failed(context);
      case RecordsState.ready:
        break;
    }
    if (widget.rows.isEmpty) return widget.empty;
    return Listener(
      // Rows follow the pointer, not the width: 36 with a mouse, 48 touched.
      onPointerDown: (e) {
        final touch = e.kind == PointerDeviceKind.touch;
        if (touch != _touch) setState(() => _touch = touch);
      },
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) {
            final shown = _c.shown;
            final selected = _c.selected;
            widget.onShown?.call([for (final r in shown) widget.keyOf(r)]);
            return Column(
              children: [
                _toolbar(context, shown),
                if (selected.isNotEmpty && widget.bulkActions.isNotEmpty)
                  RecordsBulkBar(
                    count: selected.length,
                    actions: widget.bulkActions,
                    keys: selected,
                    onClear: _c.clear,
                  ),
                Expanded(
                  child:
                      WindowClass.ofWidth(box.maxWidth) == WindowClass.compact
                      ? _cards(shown)
                      : _table(context, shown),
                ),
                const Divider(height: 1),
                _footer(shown),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _failed(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.recordsFailed, key: const ValueKey('records-failed')),
          const SizedBox(height: AppSpacing.sm),
          if (widget.onRetry case final retry?)
            FilledButton(
              key: const ValueKey('records-retry'),
              onPressed: retry,
              child: Text(l10n.recordsTryAgain),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, List<T> shown) {
    final l10n = context.l10n;
    final counts = chipCounts(
      widget.rows,
      _c.query.text,
      searchText: widget.searchText,
      chips: widget.chips,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: _filterWidth,
            child: TextField(
              key: const ValueKey('records-filter'),
              controller: _filter,
              focusNode: _filterFocus,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.filter_list),
                hintText: l10n.recordsFilter,
                isDense: true,
              ),
              onChanged: (t) => _c.setQuery(_c.query.copyWith(text: t)),
            ),
          ),
          for (final c in widget.chips)
            FilterChip(
              key: ValueKey('records-chip-${c.id}'),
              label: Text('${c.label} ${counts[c.id] ?? 0}'),
              selected: _c.query.chip == c.id,
              onSelected: (on) =>
                  _c.setQuery(_c.query.copyWith(chip: () => on ? c.id : null)),
            ),
          if (widget.columns.any((c) => c.hideable))
            MenuAnchor(
              menuChildren: [
                for (final c in widget.columns)
                  if (c.hideable)
                    CheckboxMenuButton(
                      key: ValueKey('records-column-${c.id}'),
                      value: !_c.hidden.contains(c.id),
                      onChanged: (_) => _toggleColumn(c.id),
                      child: Text(c.label),
                    ),
              ],
              builder: (context, menu, _) => IconButton(
                key: const ValueKey('records-columns'),
                tooltip: l10n.recordsColumns,
                icon: const Icon(Icons.view_column_outlined),
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, List<T> shown) {
    final columns = _columns;
    final selected = _c.selected;
    final selectedShown = shown
        .where((r) => selected.contains(widget.keyOf(r)))
        .length;
    final rowHeight = _touch ? kMinInteractiveDimension : recordRowHeight;
    T? focusedRow() =>
        shown.isEmpty ? null : shown[_c.focused.clamp(0, shown.length - 1)];
    return Shortcuts(
      shortcuts: recordsShortcuts,
      child: Actions(
        actions: recordsActions(
          focusFilter: _filterFocus.requestFocus,
          move: _c.move,
          open: () {
            if (focusedRow() case final r?) widget.onOpen(r);
          },
          tick: () {
            if (!_selectable) return;
            if (focusedRow() case final r?) {
              final k = widget.keyOf(r);
              _c.tick(k, on: !selected.contains(k));
            }
          },
          selectShown: () {
            if (_selectable) _c.selectShown(on: true);
          },
        ),
        child: Focus(
          key: const ValueKey('records-rows'),
          focusNode: _rowsFocus,
          child: Column(
            children: [
              // The header stays while the rows scroll under it.
              RecordsHeader<T>(
                columns: columns,
                query: _c.query,
                onSort: _c.sortBy,
                shown: shown.length,
                selectedShown: selectedShown,
                onSelectShown: (on) => _c.selectShown(on: on),
                selectable: _selectable,
                actionsWidth: recordActionsWidth(rowHeight),
                dense: !_touch,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = shown[i];
                    final key = widget.keyOf(r);
                    return RecordRow<T>(
                      key: ValueKey('records-row-$key'),
                      row: r,
                      columns: columns,
                      actions: widget.rowActions?.call(r) ?? const [],
                      onOpen: () {
                        // A clicked row brings the keyboard to the table.
                        _rowsFocus.requestFocus();
                        _c.focus(i);
                        widget.onOpen(r);
                      },
                      selected: selected.contains(key),
                      onTick: (on) => _c.tick(key, on: on),
                      focused: _rowsFocus.hasFocus && i == _c.focused,
                      minHeight: rowHeight,
                      selectable: _selectable,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cards(List<T> shown) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.md),
    itemCount: shown.length,
    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, i) {
      final r = shown[i];
      final key = widget.keyOf(r);
      final selected = _c.selected.contains(key);
      // The card's words name its tap; its tick is a visible box beside it.
      final card = MergeSemantics(
        child: InkWell(
          key: ValueKey('records-card-$key'),
          onTap: () => widget.onOpen(r),
          // parity: records-card-tick
          onLongPress: _selectable
              ? () => _c.tick(key, on: !selected)
              : null,
          child: widget.cardBuilder(context, r),
        ),
      );
      if (!_selectable) return card;
      return Row(
        children: [
          Checkbox(
            key: ValueKey('records-card-tick-$key'),
            semanticLabel: context.l10n.recordsSelectRow,
            value: selected,
            onChanged: (v) => _c.tick(key, on: v ?? false),
          ),
          Expanded(child: card),
        ],
      );
    },
  );

  Widget _footer(List<T> shown) {
    final amountOf = widget.amountOf;
    final selected = _c.selected;
    final selection = [
      for (final r in shown)
        if (selected.contains(widget.keyOf(r))) r,
    ];
    final scope = selection.isEmpty ? TotalScope.shown : TotalScope.selection;
    return RecordsFooter(
      shown: shown.length,
      loaded: widget.rows.length,
      complete: widget.complete,
      totals: amountOf == null
          ? const {}
          : totalsByCurrency(
              scope == TotalScope.selection ? selection : shown,
              amountOf,
            ),
      scope: scope,
      format: widget.formatAmount ?? (c, m) => '$m $c',
      dropped: _c.dropped,
    );
  }
}

/// The filter field's width beside the chips.
const double _filterWidth = 280;
