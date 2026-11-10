// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- a list line that fits a phone: a title and a caption on the
// left, an amount and a status (or one button) on the right. The whole line
// opens what it names.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import 'kit_metrics.dart';

class TwoLineRow extends StatelessWidget {
  const TwoLineRow({
    super.key,
    required this.title,
    required this.caption,
    required this.amount,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  final String title;

  /// The second line; a widget, so a part of it can carry a colour.
  final Widget caption;
  final String amount;
  final VoidCallback onTap;
  final Widget? leading;

  /// Under the amount: a status chip or one button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: KitMetrics.gap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
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
                children: [
                  Text(
                    amount,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lines in one bordered block, hairlines between them.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: AppRadius.xlAll,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: Column(
          children: [
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const Divider(height: 1),
              row,
            ],
          ],
        ),
      ),
    );
  }
}
