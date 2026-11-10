// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- a status in words on a tint: every status is a word as well
// as a colour. The tints come from the ambient ColorScheme.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/personal_theme.dart';

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

/// The (tint, colour) pair of [tone]: the semantic tokens [t] (the table the
/// personal layer reads, and its brightness's copy under the workspace
/// theme) for the four meanings — "info" is a blue, never the green of "ok"
/// — and the ambient [scheme]'s own quiet surface and secondary text for
/// neutral, so it never reads as a meaning.
(Color, Color) statusColorsOf(
  PersonalTheme t,
  StatusTone tone, {
  required ColorScheme scheme,
}) => switch (tone) {
  StatusTone.due => (t.dangerTint, t.danger),
  StatusTone.info => (t.infoTint, t.info),
  StatusTone.warn => (t.warningTint, t.warning),
  StatusTone.ok => (t.successTint, t.success),
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
    final (background, foreground) = statusColorsOf(
      PersonalTheme.of(context),
      tone,
      scheme: theme.colorScheme,
    );
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
