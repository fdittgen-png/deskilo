// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- how a bulk flow ended, honestly: what went through, what did
// not and why, and one button to leave. Nothing is reported done that the
// server did not do; what failed stays where it was asked for.
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/personal_theme.dart';
import 'bottom_action_bar.dart';
import 'kit_metrics.dart';
import 'status_chip.dart';
import 'two_line_row.dart';

/// One line of a result: what, the detail, and (when done) the word for
/// what happened to it.
typedef ResultLine = ({String title, String detail, String outcome});

class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.notDone,
    required this.notDoneHeading,
    required this.staysNote,
    required this.doneLabel,
    required this.onDone,
  });

  final String title;
  final String subtitle;
  final List<ResultLine> done;

  /// What did not go through; [ResultLine.detail] says why.
  final List<ResultLine> notDone;
  final String notDoneHeading;

  /// Where what failed stays ("It stays in To do until it is fixed.").
  final String staysNote;
  final String doneLabel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = PersonalTheme.of(context);
    Widget line(ResultLine l, {required bool ok}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (!ok) ...[
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: KitMetrics.gap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: theme.textTheme.titleSmall),
                Text(
                  l.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ok ? scheme.onSurfaceVariant : scheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (ok) StatusChip(label: l.outcome, tone: StatusTone.ok),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.mdAll,
            children: [
              // Something was done: a check in the ok tone, even when part
              // failed (the list says what); nothing was done: the alert.
              Icon(
                done.isNotEmpty ? Icons.check_circle : Icons.error_outline,
                size: 56,
                color: done.isNotEmpty ? tokens.success : tokens.danger,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              if (done.isNotEmpty)
                RowList(rows: [for (final l in done) line(l, ok: true)]),
              if (notDone.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(notDoneHeading, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                RowList(rows: [for (final l in notDone) line(l, ok: false)]),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  staysNote,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        BottomActionBar(
          actions: [
            FilledButton(
              key: const ValueKey('result-done'),
              onPressed: onDone,
              child: Text(doneLabel),
            ),
          ],
        ),
      ],
    );
  }
}
