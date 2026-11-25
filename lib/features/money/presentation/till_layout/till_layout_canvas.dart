// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the editor's grid: each cell drawn at its place and span, a tap selects it; the toolbar of the selected cell
// moves and resizes it one step at a time, every button disabled when its step would not fit; the picker of a new widget.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/service_item.dart';
import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';
import 'till_layout_words.dart';

/// The height of one grid row in the editor.
const double _rowHeight = 56;

class TillLayoutCanvas extends StatelessWidget {
  const TillLayoutCanvas({super.key, required this.grid, required this.selected, required this.onSelect});

  final TillGrid grid;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final colWidth = box.maxWidth / grid.cols;
        return Container(
          key: const ValueKey('till-layout-canvas'),
          height: grid.rows * _rowHeight,
          decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
          child: Stack(
            children: [
              for (var i = 0; i < grid.cells.length; i++)
                Positioned(
                  left: grid.cells[i].col * colWidth,
                  top: grid.cells[i].row * _rowHeight,
                  width: grid.cells[i].colSpan * colWidth,
                  height: grid.cells[i].rowSpan * _rowHeight,
                  child: Padding(
                    padding: AppSpacing.xsAll,
                    child: Material(
                      color: i == selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                      child: InkWell(
                        key: ValueKey('till-layout-cell-$i'),
                        onTap: () => onSelect(i),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Text(
                              _cellLabel(l10n, grid.cells[i]),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _cellLabel(AppLocalizations l10n, TillCell c) {
  final f = c.function;
  if (f != null) return tillFunctionName(l10n, f);
  if (c.kind == TillWidgetKind.itemKey && c.label.isNotEmpty) return c.label;
  return tillWidgetName(l10n, c.kind);
}

class TillCellToolbar extends StatelessWidget {
  const TillCellToolbar({super.key, required this.grid, required this.index, required this.onStep, required this.onRemove});

  final TillGrid grid;
  final int index;
  final ValueChanged<TillCellStep> onStep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (step, words, icon) in tillSteps(l10n))
          IconButton.outlined(
            key: ValueKey('till-layout-step-${step.name}'),
            tooltip: words,
            icon: Icon(icon),
            onPressed: stepCell(grid, index, step) == null ? null : () => onStep(step),
          ),
        IconButton.outlined(
          key: const ValueKey('till-layout-remove'),
          tooltip: l10n.tillLayoutRemoveCell,
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// A widget chosen in the picker: its kind and, for a key, what it sells or runs.
typedef TillPickedWidget = ({TillWidgetKind kind, Map<String, Object?> params});

/// One choice of a picker sheet: a heading line when [heading] is given, then a tile per [choices] entry.
Future<T?> _choose<T>(BuildContext context, List<(T, String, String)> choices, {String? heading}) => showAppSheet<T>(
  context: context,
  showDragHandle: true,
  builder: (c) => ListView(
    shrinkWrap: true,
    children: [
      if (heading != null) ListTile(title: Text(heading, style: Theme.of(c).textTheme.titleMedium)),
      for (final (value, key, words) in choices) ListTile(key: ValueKey(key), title: Text(words), onTap: () => Navigator.of(c).pop(value)),
    ],
  ),
);

/// Asks which widget to add: a tool, a function key with its function, or an item key with an item of the business.
Future<TillPickedWidget?> showTillWidgetPicker(BuildContext context, Future<List<ServiceItem>> Function() loadItems) async {
  final l10n = context.l10n;
  final kind = await _choose(context, [
    for (final k in TillWidgetKind.values)
      if (k != TillWidgetKind.unknown && k != TillWidgetKind.categoryKey) (k, 'till-layout-add-${k.wire}', tillWidgetName(l10n, k)),
  ]);
  if (kind == null || !context.mounted) return null;
  return switch (kind) {
    TillWidgetKind.functionKey => _pickFunction(context, kind),
    TillWidgetKind.itemKey => _pickItem(context, loadItems, kind),
    _ => (kind: kind, params: const <String, Object?>{}),
  };
}

Future<TillPickedWidget?> _pickFunction(BuildContext context, TillWidgetKind kind) async {
  final l10n = context.l10n;
  final f = await _choose(context, heading: l10n.tillLayoutChooseFunction, [
    for (final f in TillFunction.values)
      if (f != TillFunction.unknown) (f, 'till-layout-fn-${f.wire}', tillFunctionName(l10n, f)),
  ]);
  return f == null ? null : (kind: kind, params: {tillCellFunctionParam: f.wire});
}

Future<TillPickedWidget?> _pickItem(BuildContext context, Future<List<ServiceItem>> Function() loadItems, TillWidgetKind kind) async {
  final l10n = context.l10n;
  final items = await loadItems();
  if (!context.mounted) return null;
  final item = await _choose(context, heading: l10n.tillLayoutChooseItem, [
    for (final s in items) if (s.active) (s, 'till-layout-item-${s.id}', s.name),
  ]);
  return item == null ? null : (kind: kind, params: tillItemKeyParams(item.id, item.name));
}
