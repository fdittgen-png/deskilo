// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- one customer's line: an initial tile, the name and what the
// line says about them, what they owe and, under it, the one action (Remind,
// Confirm, Match). #4492 — on a wide window the customers are a records
// table (invoicing_customers_table.dart); this line is the phone's.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'kit_metrics.dart';

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
    required this.owes,
    required this.onTap,
    this.action,
  });

  final String name;

  /// The phone's second line: "2 invoices · 50 days late".
  final Widget caption;

  /// What they owe, one line per currency.
  final List<String> owes;
  final VoidCallback onTap;

  /// The one action (a tonal button), or nothing.
  final Widget? action;

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
    final Widget body = Row(
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
