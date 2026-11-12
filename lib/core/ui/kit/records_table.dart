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
    super.key,
  });

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
  late RecordsQuery _query = widget.initialQuery;
  Set<String> _selected = {};
  int _dropped = 0;
  int _focused = 0;
  bool _touch = false;
  Set<String> _hidden = {};
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
      _store.read().then((v) {
        if (!mounted || v == null || v.isEmpty) return;
        setState(() => _hidden = v.split(',').toSet());
      }, onError: (Object _) {}),
    );
  }

  @override
  void didUpdateWidget(RecordsTable<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.rows, widget.rows)) {
      final r = reconcileSelection(_selected, widget.rows.map(widget.keyOf));
      _selected = r.kept;
      if (r.dropped > 0) _dropped = r.dropped;
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    _rowsFocus.dispose();
    super.dispose();
  }

  List<RecordColumn<T>> get _columns => [
    for (final c in widget.columns)
      if (!c.hideable || !_hidden.contains(c.id)) c,
  ];

  List<T> _shown() => queryRows(
    widget.rows,
    _query,
    searchText: widget.searchText,
    chips: widget.chips,
    columns: widget.columns,
  );

  /// The selection kept to what [shown] holds: a filter that hides a row
  /// takes it out of the selection, so an action never reaches a hidden row.
  void _setQuery(RecordsQuery q) => setState(() {
    _query = q;
    final r = reconcileSelection(_selected, _shown().map(widget.keyOf));
    _selected = r.kept;
    _focused = 0;
  });

  void _sort(String column) => _setQuery(
    _query.sortColumn == column
        ? _query.copyWith(ascending: !_query.ascending)
        : _query.copyWith(sortColumn: () => column, ascending: true),
  );

  void _tick(String key, bool on) => setState(() {
    _selected = on ? {..._selected, key} : ({..._selected}..remove(key));
    _dropped = 0;
  });

  void _selectShown(List<T> shown, bool on) => setState(() {
    final keys = shown.map(widget.keyOf).toSet();
    _selected = on ? {..._selected, ...keys} : _selected.difference(keys);
    _dropped = 0;
  });

  void _toggleColumn(String id) {
    setState(() {
      _hidden = _hidden.contains(id)
          ? ({..._hidden}..remove(id))
          : {..._hidden, id};
    });
    _store.write(_hidden.isEmpty ? null : _hidden.join(',')).ignore();
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
      child: LayoutBuilder(
        builder: (context, box) {
          final shown = _shown();
          return Column(
            children: [
              _toolbar(context, shown),
              if (_selected.isNotEmpty && widget.bulkActions.isNotEmpty)
                RecordsBulkBar(
                  count: _selected.length,
                  actions: widget.bulkActions,
                  keys: _selected,
                  onClear: () => setState(() => _selected = {}),
                ),
              Expanded(
                child: WindowClass.ofWidth(box.maxWidth) == WindowClass.compact
                    ? _cards(shown)
                    : _table(context, shown),
              ),
              const Divider(height: 1),
              _footer(shown),
            ],
          );
        },
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
      _query.text,
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
            width: recordsFilterWidth,
            child: TextField(
              key: const ValueKey('records-filter'),
              controller: _filter,
              focusNode: _filterFocus,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.filter_list),
                hintText: l10n.recordsFilter,
                isDense: true,
              ),
              onChanged: (t) => _setQuery(_query.copyWith(text: t)),
            ),
          ),
          for (final c in widget.chips)
            FilterChip(
              key: ValueKey('records-chip-${c.id}'),
              label: Text('${c.label} ${counts[c.id] ?? 0}'),
              selected: _query.chip == c.id,
              onSelected: (on) =>
                  _setQuery(_query.copyWith(chip: () => on ? c.id : null)),
            ),
          if (widget.columns.any((c) => c.hideable))
            MenuAnchor(
              menuChildren: [
                for (final c in widget.columns)
                  if (c.hideable)
                    CheckboxMenuButton(
                      key: ValueKey('records-column-${c.id}'),
                      value: !_hidden.contains(c.id),
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
    final selectedShown = shown
        .where((r) => _selected.contains(widget.keyOf(r)))
        .length;
    void move(int by) {
      if (shown.isEmpty) return;
      setState(() => _focused = (_focused + by).clamp(0, shown.length - 1));
    }

    final rowHeight = _touch ? kMinInteractiveDimension : recordRowDeskHeight;
    T? focusedRow() =>
        shown.isEmpty ? null : shown[_focused.clamp(0, shown.length - 1)];
    return Shortcuts(
      shortcuts: recordsShortcuts,
      child: Actions(
        actions: recordsActions(
          focusFilter: _filterFocus.requestFocus,
          move: move,
          open: () {
            if (focusedRow() case final r?) widget.onOpen(r);
          },
          tick: () {
            if (!_selectable) return;
            if (focusedRow() case final r?) {
              final k = widget.keyOf(r);
              _tick(k, !_selected.contains(k));
            }
          },
          selectShown: () {
            if (_selectable) _selectShown(shown, true);
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
                query: _query,
                onSort: _sort,
                shown: shown.length,
                selectedShown: selectedShown,
                onSelectShown: (on) => _selectShown(shown, on),
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
                        setState(() => _focused = i);
                        widget.onOpen(r);
                      },
                      selected: _selected.contains(key),
                      onTick: (on) => _tick(key, on),
                      focused: _rowsFocus.hasFocus && i == _focused,
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
      return InkWell(
        key: ValueKey('records-card-$key'),
        onTap: () => widget.onOpen(r),
        onLongPress: _selectable
            ? () => _tick(key, !_selected.contains(key))
            : null,
        child: widget.cardBuilder(context, r),
      );
    },
  );

  Widget _footer(List<T> shown) {
    final amountOf = widget.amountOf;
    final selection = [
      for (final r in shown)
        if (_selected.contains(widget.keyOf(r))) r,
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
      dropped: _dropped,
    );
  }
}

/// The filter field's width beside the chips.
const double recordsFilterWidth = 280;

/// A desk row's height with a mouse; touched, a row is 48.
const double recordRowDeskHeight = 36;
