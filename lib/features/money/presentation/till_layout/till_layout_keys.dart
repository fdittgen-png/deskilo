// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till's keys as its published layout places them. A till without a published layout, or a business
// without till layouts, keeps the generated keys of #4366 unchanged. An item key whose item is no longer sold is shown
// "No longer for sale" and disabled: never a crash, and the rest of the sale goes on. The layout is read once per till
// screen, so a layout published during a sale reaches the till at its next session.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart' show enabledFeaturesSyncProvider;
import '../../domain/counter_till.dart';
import '../../domain/till_layout.dart';
import '../../providers/till_layout_providers.dart';
import '../till_keys.dart';
import 'till_layout_words.dart';

/// The height of one row of a laid-out till.
const double _rowHeight = 72;

class TillKeysOrLayout extends ConsumerWidget {
  const TillKeysOrLayout({
    super.key,
    required this.workspaceId,
    required this.tillId,
    required this.items,
    required this.onTap,
    required this.onPayCash,
    required this.onNext,
  });

  final String workspaceId;
  final String? tillId;
  final AsyncValue<List<TillKey>> items;
  final void Function(TillKey) onTap;
  final VoidCallback onPayCash;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generated = TillKeys(key: const ValueKey('till-keys'), items: items, onTap: onTap);
    final till = tillId;
    if (till == null || !ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.counterTillLayout)) return generated;
    final layout = ref.watch(tillPublishedLayoutProvider((workspaceId: workspaceId, tillId: till))).value;
    if (layout == null || layout.pages.isEmpty) return generated;
    return _LaidOut(layout: layout, items: items.value ?? const [], onTap: onTap, onPayCash: onPayCash, onNext: onNext);
  }
}

class _LaidOut extends StatefulWidget {
  const _LaidOut({required this.layout, required this.items, required this.onTap, required this.onPayCash, required this.onNext});

  final TillLayout layout;
  final List<TillKey> items;
  final void Function(TillKey) onTap;
  final VoidCallback onPayCash;
  final VoidCallback onNext;

  @override
  State<_LaidOut> createState() => _LaidOutState();
}

class _LaidOutState extends State<_LaidOut> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = widget.layout.pages;
    return LayoutBuilder(
      builder: (context, box) {
        final grids = pages[_page].grids;
        // the size the window reaches, or the largest one the page has below it
        final size = TillLayoutSize.values.reversed.firstWhere(
          (s) => s.width <= TillLayoutSize.forWidth(box.maxWidth).width && grids.containsKey(s),
          orElse: () => grids.keys.first,
        );
        final grid = grids[size]!;
        final colWidth = box.maxWidth / grid.cols;
        return SingleChildScrollView(
          key: const ValueKey('till-layout-keys'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pages.length > 1)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      ChoiceChip(
                        key: ValueKey('till-layout-tab-$i'),
                        label: Text(pages[i].name),
                        selected: i == _page,
                        onSelected: (_) => setState(() => _page = i),
                      ),
                  ],
                ),
              SizedBox(
                height: grid.rows * _rowHeight,
                child: Stack(
                  children: [
                    for (var i = 0; i < grid.cells.length; i++)
                      Positioned(
                        left: grid.cells[i].col * colWidth,
                        top: grid.cells[i].row * _rowHeight,
                        width: grid.cells[i].colSpan * colWidth - AppSpacing.xs,
                        height: grid.cells[i].rowSpan * _rowHeight - AppSpacing.xs,
                        child: _cell(context, grid.cells[i], i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(BuildContext context, TillCell c, int i) {
    final l10n = context.l10n;
    final key = ValueKey('till-layout-key-$i');
    switch (c.kind) {
      case TillWidgetKind.itemKey:
        final item = widget.items.where((k) => k.id == c.itemId).firstOrNull;
        if (item == null) {
          return OutlinedButton(key: key, onPressed: null, child: Text('${c.label}\n${l10n.tillLayoutGone}', textAlign: TextAlign.center));
        }
        return FilledButton.tonal(key: key, onPressed: () => widget.onTap(item), child: Text(item.name, textAlign: TextAlign.center));
      case TillWidgetKind.functionKey:
        final f = c.function!;
        final run = switch (f) {
          TillFunction.payCash => widget.onPayCash,
          TillFunction.nextCustomer => widget.onNext,
          // the other functions are reached in the basket for now; their key is shown, not yet wired here
          _ => null,
        };
        return FilledButton(key: key, onPressed: run, child: Text(tillFunctionName(l10n, f), textAlign: TextAlign.center));
      default:
        // the tools have their place beside the keys today (the basket, its total and the scan field)
        return Card(key: key, child: Center(child: Text(tillWidgetName(l10n, c.kind), textAlign: TextAlign.center)));
    }
  }
}
