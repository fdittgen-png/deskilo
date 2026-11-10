// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the "To do" card: its heading with how many entries wait,
// the entries ([TodoRow]s) or, when there are none, the quiet line in their
// place, and a footer (the line that says how reminders go out).
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import 'kit_card.dart';
import 'kit_metrics.dart';

class TodoCard extends StatelessWidget {
  const TodoCard({
    super.key,
    required this.title,
    required this.rows,
    required this.quiet,
    this.count,
    this.footer,
  });

  final String title;

  /// The entries, the first one with the filled button.
  final List<Widget> rows;

  /// Shown instead of [rows] when there are none ("You are all caught up.").
  final Widget quiet;

  /// How many entries wait, when more wait than [rows] shows.
  final int? count;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (rows.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: AppRadius.xxlAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    child: Text(
                      '${count ?? rows.length}',
                      style: theme.textTheme.labelMedium?.emphasised.copyWith(
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KitMetrics.gap),
          if (rows.isEmpty)
            quiet
          else
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) const Divider(height: KitMetrics.gap * 2),
              row,
            ],
          if (footer != null) ...[
            const Divider(height: KitMetrics.gap * 2),
            footer!,
          ],
        ],
      ),
    );
  }
}
