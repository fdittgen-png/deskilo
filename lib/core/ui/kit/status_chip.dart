// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- a status in words on a tint: every status is a word as well
// as a colour. The tints come from the ambient ColorScheme.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/status_colors.dart';

/// What a status says about its row.
enum StatusTone {
  /// Late, refused, failed.
  due,

  /// Money on its way, something to confirm.
  info,

  /// Due today, on hold.
  warn,

  /// Paid, done.
  ok,

  /// Nothing to act on.
  neutral,
}

/// The (background, foreground) pair of [tone] in [scheme].
(Color, Color) statusColorsOf(ColorScheme scheme, StatusTone tone) =>
    switch (tone) {
      StatusTone.due => (scheme.errorContainer, scheme.onErrorContainer),
      StatusTone.info => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      StatusTone.warn => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      StatusTone.ok => (
        scheme.surfaceContainerHighest,
        AppStatusColors.successTextOf(scheme.brightness),
      ),
      StatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = statusColorsOf(theme.colorScheme, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.xxlAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
