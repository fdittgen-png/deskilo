// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4483 -- what stands above the items: the filters (the search, the place and "without a home place"), stacked
// above the cards on a phone, and at the desk the toolbar above the grid. Its left part holds the filters; its right
// part acts on the row selected in the grid: the item's worded actions, each enabled by the member's rights, Open and
// the way to clear the selection. With nothing selected it says how to act on an item and offers what acts on the
// list: Add an item.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/kit/filter_chips.dart';
import '../../../core/ui/kit/kit_metrics.dart';
import '../../../core/ui/motion.dart';
import '../domain/stock_config.dart';
import 'stock_item_actions.dart';

/// The search field's width beside the place in the toolbar.
const double _searchWidth = 280;

/// The widest the selected item's name stands in the toolbar before it ends in an ellipsis.
const double _selectedNameWidth = 280;

/// The search, the place and "all" or "without a home place".
class StockItemsFilters extends StatelessWidget {
  const StockItemsFilters({
    super.key,
    required this.search,
    required this.places,
    required this.separator,
    required this.place,
    required this.noHome,
    required this.onQuery,
    required this.onSubmitted,
    required this.onPlace,
    required this.onNoHome,
    this.wide = false,
  });

  final TextEditingController search;

  /// The business's places, the place filter's choices.
  final List<StockPlaceConfig> places;
  final String separator;
  final String? place;
  final bool noHome;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String?> onPlace;
  final ValueChanged<bool> onNoHome;

  /// In the desk's toolbar: one row that wraps, the search at its own width.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = AppTextField(
      key: const ValueKey('stock-registry-search'),
      controller: search,
      fieldKey: 'search',
      label: l10n.stockRegistrySearch,
      onChanged: onQuery,
      onSubmitted: onSubmitted,
    );
    final choices = [
      ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: KitMetrics.dropdownMaxWidth,
        ),
        child: AppDropdownField<String?>(
          key: const ValueKey('stock-registry-place'),
          label: l10n.stockRegistryPlaceFilter,
          value: place,
          items: [
            (null, l10n.stockRegistryAllPlaces),
            for (final p in [
              ...places.where((p) => !p.virtual),
            ]..sort((a, b) => a.addressPath.compareTo(b.addressPath)))
              (p.id, p.addressPath.split(stockAddressJoint).join(separator)),
          ],
          onChanged: noHome ? null : onPlace,
        ),
      ),
      FilterChips<bool>(
        key: const ValueKey('stock-registry-home-filter'),
        options: [
          (
            value: false,
            label: l10n.stockItemFilterAll,
            key: const ValueKey('stock-registry-all'),
          ),
          (
            value: true,
            label: l10n.stockItemFilterNoHome,
            key: const ValueKey('stock-registry-no-home'),
          ),
        ],
        selected: noHome,
        onSelected: onNoHome,
      ),
    ];
    if (wide) {
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: _searchWidth, child: field),
          ...choices,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const FormGap.small(),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...choices,
            HelpDot(l10n.stockItemsTitle, anchor: HelpAnchor.moneyStockActions),
          ],
        ),
      ],
    );
  }
}

/// The desk's toolbar above the grid: [filters] on its left, and on its right the [actions] of the row whose item
/// is named [selected], or, with none selected, the hint and Add an item ([onAdd], null for who may not add).
class StockItemsToolbar extends StatelessWidget {
  const StockItemsToolbar({
    super.key,
    required this.filters,
    required this.selected,
    required this.actions,
    required this.onOpen,
    required this.onClear,
    this.onAdd,
  });

  final Widget filters;

  /// The selected row's name; null when no row is selected.
  final String? selected;

  /// The selected row's actions, those the member may not use disabled.
  final List<StockItemAction> actions;
  final VoidCallback onOpen;
  final VoidCallback onClear;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = selected;
    final help = HelpDot(
      l10n.stockItemsTitle,
      anchor: HelpAnchor.moneyStockActions,
    );
    final Widget acting = name == null
        ? Wrap(
            key: const ValueKey('stock-items-idle'),
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.ads_click, color: scheme.onSurfaceVariant),
              Text(
                l10n.stockItemsSelectHint,
                key: const ValueKey('stock-items-select-hint'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onAdd case final add?)
                FilledButton.icon(
                  key: const ValueKey('stock-item-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.stockItemAddButton),
                  onPressed: add,
                ),
              help,
            ],
          )
        : DecoratedBox(
            key: const ValueKey('stock-items-acting'),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Padding(
              padding: AppSpacing.xsAll,
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _selectedNameWidth,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.xs,
                      children: [
                        Icon(Icons.check_circle, color: scheme.primary),
                        Flexible(
                          child: Text(
                            name,
                            key: const ValueKey('stock-items-selected-name'),
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final a in actions)
                    TextButton.icon(
                      key: a.key,
                      icon: Icon(a.icon),
                      label: Text(a.label),
                      onPressed: a.allowed ? () => unawaited(a.run()) : null,
                    ),
                  FilledButton.tonalIcon(
                    key: const ValueKey('stock-items-open'),
                    icon: const Icon(Icons.open_in_full),
                    label: Text(l10n.financesOpenDocument),
                    onPressed: onOpen,
                  ),
                  IconButton(
                    key: const ValueKey('stock-items-clear-selection'),
                    tooltip: l10n.recordsClearSelection,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
                  help,
                ],
              ),
            ),
          );
    return Material(
      key: const ValueKey('stock-items-toolbar'),
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.lgAll,
      child: Padding(
        padding: AppSpacing.smAll,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            filters,
            AnimatedSwitcher(
              duration: AppMotion.viewSwitchOf(context),
              child: acting,
            ),
          ],
        ),
      ),
    );
  }
}
