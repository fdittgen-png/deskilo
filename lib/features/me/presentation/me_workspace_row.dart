// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';

/// One of my spaces on Me › Home: a soft card with the identity on top —
/// avatar, name, role, what I marked it with, one options menu — and the
/// environments to enter below it, side by side at every width.
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

  /// The heart, the stars and the options menu of this row.
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.xxlAll,
          // The space I used last wears a quiet ring, not a different card.
          border: Border.all(
            color: lastUsed
                ? scheme.primary.withValues(alpha: .45)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                          style: theme.textTheme.titleMedium?.strong,
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?controls,
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // The right edge keeps the card's own padding: the menu above
              // reaches further out so its tap target stays 48dp.
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Row(children: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
