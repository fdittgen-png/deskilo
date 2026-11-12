// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3606 (desk K1) — the parts a records table is drawn from: its header (the
// sort controls and the select-shown box), a row (its cells, its tick, its
// first action on hover or focus and the rest behind ⋯), the bar of actions
// on the selection and the footer (count, totals per currency with their
// scope, and whether everything is read). The row menu is the plain ⋯ menu
// until RowMenu (#3611) takes the same declared actions.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/context_l10n.dart';
import '../../theme/app_spacing.dart';
import 'records_table_model.dart';

/// The cells of a row (or the header) in their columns.
Widget recordCells<T>(
  List<RecordColumn<T>> columns,
  List<Widget> cells, {
  Widget? leading,
  Widget? trailing,
}) => Row(
  children: [
    ?leading,
    for (final (i, c) in columns.indexed)
      Expanded(
        flex: c.flex,
        child: Align(
          alignment: c.numeric
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: c.numeric
              ? DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  child: cells[i],
                )
              : cells[i],
        ),
      ),
    ?trailing,
  ],
);

/// The header: a label per column (a sort control where it sorts), the
/// box that selects what is shown, and room for the row's actions.
class RecordsHeader<T> extends StatelessWidget {
  const RecordsHeader({
    required this.columns,
    required this.query,
    required this.onSort,
    required this.shown,
    required this.selectedShown,
    required this.onSelectShown,
    required this.selectable,
    required this.actionsWidth,
    this.dense = false,
    super.key,
  });

  /// Whether the rows under it are a mouse's short rows.
  final bool dense;

  final List<RecordColumn<T>> columns;
  final RecordsQuery query;
  final ValueChanged<String> onSort;
  final int shown;
  final int selectedShown;
  final ValueChanged<bool> onSelectShown;
  final bool selectable;
  final double actionsWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget label(RecordColumn<T> c) {
      final text = Text(c.label.toUpperCase(), style: style);
      if (c.sortKey == null) return text;
      final on = query.sortColumn == c.id;
      return TextButton.icon(
        key: ValueKey('records-sort-${c.id}'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        onPressed: () => onSort(c.id),
        iconAlignment: IconAlignment.end,
        icon: Icon(
          on && !query.ascending ? Icons.arrow_downward : Icons.arrow_upward,
          size: AppSpacing.md,
          color: on ? null : Colors.transparent,
        ),
        label: Tooltip(message: l10n.recordsSortBy(c.label), child: text),
      );
    }

    final all = shown > 0 && selectedShown == shown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: recordCells(
        columns,
        [for (final c in columns) label(c)],
        leading: selectable
            ? Checkbox(
                key: const ValueKey('records-select-shown'),
                materialTapTargetSize: dense
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                visualDensity: dense
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                tristate: true,
                value: all ? true : (selectedShown == 0 ? false : null),
                semanticLabel: l10n.recordsSelectShown(shown),
                onChanged: (_) => onSelectShown(!all),
              )
            : null,
        trailing: SizedBox(width: actionsWidth),
      ),
    );
  }
}

/// One row: its tick, its cells, its first action while hovered or focused
/// and every action behind ⋯ (also on the secondary click and a long press).
class RecordRow<T> extends StatefulWidget {
  const RecordRow({
    required this.row,
    required this.columns,
    required this.actions,
    required this.onOpen,
    required this.selected,
    required this.onTick,
    required this.focused,
    required this.minHeight,
    required this.selectable,
    super.key,
  });

  final T row;
  final List<RecordColumn<T>> columns;
  final List<RecordAction<T>> actions;
  final VoidCallback onOpen;
  final bool selected;
  final ValueChanged<bool> onTick;
  final bool focused;
  final double minHeight;
  final bool selectable;

  @override
  State<RecordRow<T>> createState() => _RecordRowState<T>();
}

class _RecordRowState<T> extends State<RecordRow<T>> {
  final _menu = MenuController();
  bool _hover = false;

  void _openMenu([Offset? at]) {
    if (widget.actions.isEmpty) return;
    _menu.open(position: at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = widget.actions.firstOrNull;
    final showFirst = first != null && (_hover || widget.focused);
    // With a mouse the row is short, and so are its controls (#3605: every
    // row action is also reached by the keyboard and the menu).
    final side = widget.minHeight;
    final dense = side < kMinInteractiveDimension;
    final buttonStyle = IconButton.styleFrom(
      tapTargetSize: dense
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      fixedSize: Size.square(side),
      minimumSize: Size.square(side),
      padding: EdgeInsets.zero,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapDown: (d) => _openMenu(d.localPosition),
        onLongPressStart: (d) => _openMenu(d.localPosition),
        child: MenuAnchor(
          controller: _menu,
          menuChildren: [
            for (final a in widget.actions)
              MenuItemButton(
                key: ValueKey('records-action-${a.id}'),
                leadingIcon: Icon(a.icon),
                onPressed: a.unavailable == null
                    ? () => a.onRun(widget.row)
                    : null,
                child: Tooltip(
                  message: a.unavailable ?? '',
                  child: Text(
                    a.label,
                    style: a.destructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ),
          ],
          child: Material(
            color: widget.selected
                ? theme.colorScheme.secondaryContainer
                : widget.focused
                ? theme.colorScheme.surfaceContainerHighest
                : Colors.transparent,
            child: InkWell(
              onTap: widget.onOpen,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: widget.minHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: recordCells(
                    widget.columns,
                    [
                      for (final c in widget.columns)
                        c.cell(context, widget.row),
                    ],
                    leading: widget.selectable
                        ? Checkbox(
                            materialTapTargetSize: dense
                                ? MaterialTapTargetSize.shrinkWrap
                                : MaterialTapTargetSize.padded,
                            visualDensity: dense
                                ? VisualDensity.compact
                                : VisualDensity.standard,
                            value: widget.selected,
                            onChanged: (v) => widget.onTick(v ?? false),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showFirst && first.unavailable == null)
                          IconButton(
                            style: buttonStyle,
                            tooltip: first.label,
                            icon: Icon(first.icon),
                            onPressed: () => first.onRun(widget.row),
                          )
                        else
                          SizedBox(width: side),
                        if (widget.actions.isNotEmpty)
                          IconButton(
                            style: buttonStyle,
                            tooltip: l10n.recordsMoreActions,
                            icon: const Icon(Icons.more_horiz),
                            onPressed: _openMenu,
                          )
                        else
                          SizedBox(width: side),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The width a row's actions take beside the cells: two controls as high
/// as the row.
double recordActionsWidth(double rowHeight) => 2 * rowHeight;

/// The actions on the selection, each naming what it does to how many.
class RecordsBulkBar extends StatelessWidget {
  const RecordsBulkBar({
    required this.count,
    required this.actions,
    required this.keys,
    required this.onClear,
    super.key,
  });

  final int count;
  final List<RecordBulkAction> actions;
  final Set<String> keys;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('records-bulk-bar'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.recordsSelected(count)),
            for (final a in actions)
              FilledButton.tonalIcon(
                key: ValueKey('records-bulk-${a.id}'),
                icon: Icon(a.icon),
                label: Text(a.label(count)),
                onPressed: () => a.onRun({...keys}),
              ),
            TextButton(
              key: const ValueKey('records-clear-selection'),
              onPressed: onClear,
              child: Text(l10n.recordsClearSelection),
            ),
          ],
        ),
      ),
    );
  }
}

/// The footer: how many rows are shown, whether everything is read, and the
/// totals of [scope] per currency, each in its own currency.
class RecordsFooter extends StatelessWidget {
  const RecordsFooter({
    required this.shown,
    required this.loaded,
    required this.complete,
    required this.totals,
    required this.scope,
    required this.format,
    this.dropped = 0,
    super.key,
  });

  final int shown;
  final int loaded;
  final bool complete;
  final Map<String, int> totals;
  final TotalScope scope;
  final String Function(String currency, int minor) format;
  final int dropped;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final currencies = totals.keys.toList()..sort();
    return Padding(
      key: const ValueKey('records-footer'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l10n.recordsShown(shown), key: const ValueKey('records-count')),
          if (!complete)
            Text(
              l10n.recordsPartlyRead(loaded),
              key: const ValueKey('records-partly-read'),
              style: muted,
            ),
          if (dropped > 0)
            Text(
              l10n.recordsDropped(dropped),
              key: const ValueKey('records-dropped'),
              style: muted,
            ),
          if (currencies.isNotEmpty)
            Text(
              scope == TotalScope.selection
                  ? l10n.recordsTotalOfSelection
                  : l10n.recordsTotalOfShown,
              key: const ValueKey('records-total-scope'),
              style: muted,
            ),
          for (final c in currencies)
            Text(
              format(c, totals[c]!),
              key: ValueKey('records-total-$c'),
              style: theme.textTheme.titleSmall,
            ),
        ],
      ),
    );
  }
}

/// The keys a table answers to: / filters, ↑ ↓ move, Enter opens, Space
/// ticks, Ctrl/⌘+A selects what is shown.
final Map<ShortcutActivator, Intent> recordsShortcuts = {
  const SingleActivator(LogicalKeyboardKey.slash): const _FocusFilter(),
  const SingleActivator(LogicalKeyboardKey.arrowDown): const _Move(1),
  const SingleActivator(LogicalKeyboardKey.arrowUp): const _Move(-1),
  const SingleActivator(LogicalKeyboardKey.enter): const _Open(),
  const SingleActivator(LogicalKeyboardKey.space): const _Tick(),
  const SingleActivator(LogicalKeyboardKey.keyA, control: true):
      const _SelectShown(),
  const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
      const _SelectShown(),
};

/// The table's keyboard actions, wired by the table.
Map<Type, Action<Intent>> recordsActions({
  required VoidCallback focusFilter,
  required ValueChanged<int> move,
  required VoidCallback open,
  required VoidCallback tick,
  required VoidCallback selectShown,
}) => {
  _FocusFilter: CallbackAction<_FocusFilter>(onInvoke: (_) => focusFilter()),
  _Move: CallbackAction<_Move>(onInvoke: (i) => move(i.by)),
  _Open: CallbackAction<_Open>(onInvoke: (_) => open()),
  _Tick: CallbackAction<_Tick>(onInvoke: (_) => tick()),
  _SelectShown: CallbackAction<_SelectShown>(onInvoke: (_) => selectShown()),
};

class _FocusFilter extends Intent {
  const _FocusFilter();
}

class _Move extends Intent {
  const _Move(this.by);
  final int by;
}

class _Open extends Intent {
  const _Open();
}

class _Tick extends Intent {
  const _Tick();
}

class _SelectShown extends Intent {
  const _SelectShown();
}
