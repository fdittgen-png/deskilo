// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0, #3674 -- a row with a leading tile: a title, an optional
// second line and a trailing chip or action. The whole row is one button when
// it has [onTap]; its [semanticLabel] is required and says what and where.
// A row that shows an amount and a status is a `TwoLineRow`.
import 'package:flutter/material.dart';

import '../../theme/personal_theme.dart';
import 'kit_metrics.dart';

class TileRow extends StatelessWidget {
  const TileRow({
    super.key,
    required this.title,
    required this.semanticLabel,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// What a screen reader says for the whole row.
  final String semanticLabel;

  /// The icon (or initial) shown inside the leading tile.
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KitMetrics.minTarget),
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: KitMetrics.tile,
              height: KitMetrics.tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: PersonalShellMetrics.controlRadiusAll,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: scheme.primary, size: 20),
                child: leading!,
              ),
            ),
            const SizedBox(width: KitMetrics.gap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: KitMetrics.gap),
            trailing!,
          ],
        ],
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      excludeSemantics: true,
      // recorder-key-exempt: the semantics of the row; its InkWell below carries the key.
      onTap: onTap,
      child: onTap == null
          ? content
          : InkWell(
              key: const ValueKey<String>('tile-row-tap'),
              borderRadius: PersonalShellMetrics.controlRadiusAll,
              onTap: onTap,
              child: content,
            ),
    );
  }
}
