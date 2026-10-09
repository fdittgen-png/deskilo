// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../workspace/domain/workspace_branding.dart';
import '../../workspace/presentation/widgets/brand_swatch.dart';
import 'hold_to_move.dart';

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
    this.environmentHint,
    this.dragIndex,
    this.brand,
  });

  /// #2313 — the space's own colour and pattern, drawn as a band down the
  /// card's leading edge so it is told apart from the others; null when
  /// the space shows none.
  final ({Color color, BrandPattern? pattern})? brand;
  final bool lastUsed;

  /// The place of this card in its (reorderable) list; null when the list
  /// cannot be reordered now (filtered, or sorted another way).
  final int? dragIndex;
  final Widget avatar;
  final String name, detail;
  final String? environmentHint;
  final List<Widget> actions;

  /// The heart, the stars and the options menu of this row.
  final Widget? controls;

  /// A hold on the avatar or the name lifts the card to move it.
  Widget _held(Widget identity) => dragIndex == null
      ? identity
      : HoldToMove(
          key: ValueKey('me-hold-move-$dragIndex'),
          index: dragIndex!,
          // The whole strip answers to the hold, not only its text.
          child: ColoredBox(color: Colors.transparent, child: identity),
        );

  Widget identity(ThemeData theme, ColorScheme scheme) => Row(
    children: [
      // No tooltip here: its long press would win the gesture the one-second
      // hold needs to lift the card.
      avatar,
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
    ],
  );

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
        child: _withBand(Padding(
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
                  Expanded(child: _held(identity(theme, scheme))),
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
              if (environmentHint case final hint?) Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.sm),
                child: Text(hint, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _withBand(Widget card) {
    final band = brand;
    if (band == null) return card;
    return ClipRRect(
      borderRadius: AppRadius.xxlAll,
      child: Stack(
        children: [
          card,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 8,
            child: BrandSwatch(
              key: const ValueKey('me-space-brand'),
              color: band.color,
              pattern: band.pattern,
            ),
          ),
        ],
      ),
    );
  }
}
