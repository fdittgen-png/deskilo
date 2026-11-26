// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- an item of the stock as the list shows it, read at a glance on a phone: its name on at most two lines,
// one line of facts (its price, what is on hand with its unit, its home place or that it has none) and a badge for
// the most pressing thing it needs.
// #4483 -- on a phone (the compact and medium window classes) the item is a card: the name with its badge, the
// facts, and the item's actions as a row of worded chips that scrolls sideways when it does not fit. Only what the
// member may do is offered, so a reader's card has no chips. The card's body opens the item; a chip opens its editor
// directly, the same editor under the same key as on the item's page.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/edge_fade_scroll.dart';
import '../../../core/ui/kit/kit_metrics.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../domain/stock_config.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import 'stock_item_actions.dart';
import 'stock_item_view.dart';

/// The home place of [row] as a person reads it, or that it has none.
String stockItemHome(
  BuildContext context,
  StockRegistryRow row,
  String separator,
) => switch (row.homeAddressPath) {
  final path? => path.split(stockAddressJoint).join(separator),
  null => context.l10n.stockRegistryNoHome,
};

/// What is on hand of [row], with its unit.
String stockItemOnHand(BuildContext context, StockRegistryRow row) => context
    .l10n
    .stockQuantityWithUnit(appFormatOf(context).quantity(row.onHand), row.unit);

/// The facts line of [row]: its price (when it has one), what is on hand and its home place.
String stockItemFacts(
  BuildContext context,
  StockRegistryRow row,
  String separator,
) => [
  if (row.priceCents case final price?) appFormatOf(context).money(price),
  context.l10n.stockRegistryOnHand(stockItemOnHand(context, row)),
  stockItemHome(context, row, separator),
].join(' · ');

/// One item of the list on a phone: [row], what it needs ([attention], most pressing first) and the [actions] the
/// member may use.
class StockItemCard extends StatelessWidget {
  const StockItemCard({
    super.key,
    required this.row,
    required this.attention,
    required this.separator,
    required this.actions,
    required this.onOpen,
  });

  final StockRegistryRow row;
  final List<StockAttention> attention;

  /// The business's address separator, for the home place.
  final String separator;

  /// The row's actions; those the member may not use are not shown.
  final List<StockItemAction> actions;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final first = attention.firstOrNull;
    final offered = [
      for (final a in actions)
        if (a.allowed) a,
    ];
    return Material(
      key: ValueKey('stock-item-${row.key}'),
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The name and the facts are one button: the item opens.
          MergeSemantics(
            child: InkWell(
              key: ValueKey('stock-item-open-${row.key}'),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(KitMetrics.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.sm,
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            key: ValueKey('stock-item-name-${row.key}'),
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (first != null)
                          StatusChip(
                            key: ValueKey('stock-item-badge-${row.key}'),
                            label: stockAttentionText(context.l10n, first),
                            tone: StatusTone.warn,
                          ),
                      ],
                    ),
                    Text(
                      stockItemFacts(context, row, separator),
                      key: ValueKey('stock-item-facts-${row.key}'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (offered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: EdgeFadeScroll(
                key: ValueKey('stock-item-chips-${row.key}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: KitMetrics.cardPadding,
                ),
                child: Row(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final a in offered)
                      ActionChip(
                        key: a.key,
                        avatar: Icon(a.icon),
                        label: Text(a.word),
                        tooltip: a.label,
                        onPressed: () => unawaited(a.run()),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
