// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// One identity, with its environment actions kept together at every width.
class MeWorkspaceRow extends StatelessWidget {
  const MeWorkspaceRow({
    super.key,
    required this.avatar,
    required this.name,
    required this.detail,
    required this.actions,
    this.lastUsed = false,
    this.controls,
  });
  final bool lastUsed;
  final Widget avatar;
  final String name, detail;
  final List<Widget> actions;

  /// Favourite, stars and move arrows of this row.
  final Widget? controls;

  @override
  Widget build(BuildContext context) => Card.outlined(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlAll,
      side: BorderSide(
        color: lastUsed
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .4)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              Tooltip(message: name, child: avatar),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .primaryValue
                          ?.emphasised,
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?controls,
            ],
          );
          // Production and development share the row, production twice as
          // wide; the row fills the width so development sits at the right.
          final environments = Row(children: actions);
          // Large text gets the same stacked identity as a small viewport;
          // environments remain next to each other, with horizontal scrolling
          // only when accessibility text cannot fit both controls.
          if (constraints.maxWidth /
                  MediaQuery.textScalerOf(context).scale(1) >=
              600) {
            return Row(
              children: [
                Expanded(child: identity),
                SizedBox(width: 340, child: environments),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: AppSpacing.xs),
              environments,
            ],
          );
        },
      ),
    ),
  );
}
