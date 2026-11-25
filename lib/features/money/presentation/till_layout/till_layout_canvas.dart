// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the editor's grid: each cell drawn at its place and span, a tap selects it; the toolbar of the selected cell
// moves and resizes it one step at a time, every button disabled when its step would not fit; the picker of a new widget.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/service_item.dart';
import '../../domain/till_layout.dart';
import '../../domain/till_layout_edits.dart';
import '../../providers/money_providers.dart' show servicesProvider;
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
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: i == selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
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

/// Asks which widget to add: a tool, a function key with its function, or an item key with an item of the business.
Future<TillPickedWidget?> showTillWidgetPicker(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final kind = await showModalBottomSheet<TillWidgetKind>(
    context: context,
    showDragHandle: true,
    builder: (c) => ListView(
      shrinkWrap: true,
      children: [
        for (final k in TillWidgetKind.values)
          if (k != TillWidgetKind.unknown && k != TillWidgetKind.categoryKey)
            ListTile(key: ValueKey('till-layout-add-${k.wire}'), title: Text(tillWidgetName(l10n, k)), onTap: () => Navigator.of(c).pop(k)),
      ],
    ),
  );
  if (kind == null || !context.mounted) return null;
  if (kind == TillWidgetKind.functionKey) {
    final f = await showModalBottomSheet<TillFunction>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l10n.tillLayoutChooseFunction, style: Theme.of(c).textTheme.titleMedium)),
          for (final f in TillFunction.values)
            if (f != TillFunction.unknown)
              ListTile(key: ValueKey('till-layout-fn-${f.wire}'), title: Text(tillFunctionName(l10n, f)), onTap: () => Navigator.of(c).pop(f)),
        ],
      ),
    );
    return f == null ? null : (kind: kind, params: {tillCellFunctionParam: f.wire});
  }
  if (kind == TillWidgetKind.itemKey) {
    final items = [for (final s in ref.read(servicesProvider).value ?? const <ServiceItem>[]) if (s.active) s];
    if (!context.mounted) return null;
    final item = await showModalBottomSheet<ServiceItem>(
      context: context,
      showDragHandle: true,
      builder: (c) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l10n.tillLayoutChooseItem, style: Theme.of(c).textTheme.titleMedium)),
          for (final s in items) ListTile(key: ValueKey('till-layout-item-${s.id}'), title: Text(s.name), onTap: () => Navigator.of(c).pop(s)),
        ],
      ),
    );
    return item == null ? null : (kind: kind, params: tillItemKeyParams(item.id, item.name));
  }
  return (kind: kind, params: const <String, Object?>{});
}
