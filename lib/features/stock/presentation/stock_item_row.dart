// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- an item of the stock as the list shows it, read at a glance on a phone: its name on at most two lines,
// one line of facts (its price, what is on hand with its unit, its home place or that it has none) and a badge for
// the most pressing thing it needs. No action crowds the row: the whole row opens the item, where each part has its
// own worded edit.
import 'package:flutter/material.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/kit/status_chip.dart';
import '../domain/stock_config.dart';
import '../domain/stock_item_attention.dart';
import '../domain/stock_registry.dart';
import 'stock_item_view.dart';

/// One row of the items list: [row] and what it needs ([attention], most pressing first).
class StockItemRow extends StatelessWidget {
  const StockItemRow({
    super.key,
    required this.row,
    required this.attention,
    required this.separator,
    required this.selected,
    required this.onOpen,
  });

  final StockRegistryRow row;
  final List<StockAttention> attention;

  /// The business's address separator, for the home place.
  final String separator;

  /// The row's item stands open beside the list.
  final bool selected;
  final VoidCallback onOpen;

  /// The facts line: the price (when there is one), what is on hand and the home place.
  String _facts(BuildContext context) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    return [
      if (row.priceCents != null) format.money(row.priceCents!),
      l10n.stockRegistryOnHand(
        l10n.stockQuantityWithUnit(format.quantity(row.onHand), row.unit),
      ),
      switch (row.homeAddressPath) {
        final path? => path.split(stockAddressJoint).join(separator),
        null => l10n.stockRegistryNoHome,
      },
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final first = attention.firstOrNull;
    return ListTile(
      key: ValueKey('stock-item-${row.key}'),
      selected: selected,
      title: Text(row.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _facts(context),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (first != null)
            StatusChip(
              key: ValueKey('stock-item-badge-${row.key}'),
              label: stockAttentionText(context.l10n, first),
              tone: StatusTone.warn,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onOpen,
    );
  }
}
