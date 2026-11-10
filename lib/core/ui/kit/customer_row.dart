// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- one customer's line: an initial tile, the name and what the
// line says about them, what they owe and, under it, the one action (Remind,
// Confirm, Match). On a wide window the same line is a table row whose
// columns align under [CustomerHeader]: customer · invoices · oldest · owes ·
// action.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'kit_metrics.dart';

/// The flex of each column: customer, invoices, oldest, owes, action.
const List<int> _flex = [5, 2, 3, 3, 3];

Widget _cells(List<Widget> cells) => Row(
  children: [
    for (final (i, cell) in cells.indexed)
      Expanded(
        flex: _flex[i],
        child: Align(
          alignment: i >= 3 ? Alignment.centerRight : Alignment.centerLeft,
          child: cell,
        ),
      ),
  ],
);

/// The header of the wide customer table.
class CustomerHeader extends StatelessWidget {
  const CustomerHeader({
    super.key,
    required this.customer,
    required this.invoices,
    required this.oldest,
    required this.owes,
  });

  final String customer;
  final String invoices;
  final String oldest;
  final String owes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _cells([
        Padding(
          padding: const EdgeInsets.only(
            left: KitMetrics.tile + KitMetrics.gap,
          ),
          child: Text(customer.toUpperCase(), style: style),
        ),
        Text(invoices.toUpperCase(), style: style),
        Text(oldest.toUpperCase(), style: style),
        Text(owes.toUpperCase(), style: style),
        const SizedBox.shrink(),
      ]),
    );
  }
}

/// The square with a customer's initial.
class InitialTile extends StatelessWidget {
  const InitialTile(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: KitMetrics.tile,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgAll,
          ),
          child: Center(
            child: Text(
              initial.toUpperCase(),
              style: theme.textTheme.titleSmall?.emphasised.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerRow extends StatelessWidget {
  const CustomerRow({
    super.key,
    required this.name,
    required this.caption,
    required this.invoices,
    required this.oldest,
    required this.owes,
    required this.onTap,
    this.action,
    this.wide = false,
  });

  final String name;

  /// The phone's second line: "2 invoices · 50 days late".
  final Widget caption;

  /// The wide table's invoices column ("2").
  final String invoices;

  /// The wide table's oldest column: a status chip.
  final Widget oldest;

  /// What they owe, one line per currency.
  final List<String> owes;
  final VoidCallback onTap;

  /// The one action (a tonal button), or nothing.
  final Widget? action;

  /// A table row under [CustomerHeader] instead of a two-line row.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final amounts = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [for (final o in owes) Text(o, style: amountStyle)],
    );
    final title = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall,
    );
    final Widget body = wide
        ? _cells([
            Row(
              children: [
                InitialTile(name),
                const SizedBox(width: KitMetrics.gap),
                Flexible(child: title),
              ],
            ),
            Text(invoices),
            oldest,
            amounts,
            action ?? const SizedBox.shrink(),
          ])
        : Row(
            children: [
              InitialTile(name),
              const SizedBox(width: KitMetrics.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    DefaultTextStyle.merge(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KitMetrics.gap),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 4,
                children: [amounts, ?action],
              ),
            ],
          );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: body,
        ),
      ),
    );
  }
}
