// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- a row of Me: a leading tile, a title, an optional second
// line and a trailing chip or action. The whole row is one button when it has
// [onTap]; its [semanticLabel] is required and says what and where.
import 'package:flutter/material.dart';

import '../../../../core/theme/personal_theme.dart';
import 'me_kit_metrics.dart';

class MeRow extends StatelessWidget {
  const MeRow({
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

  /// The icon (or initial) shown inside the 36 dp tile.
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: MeKitMetrics.minTarget),
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: MeKitMetrics.tile,
              height: MeKitMetrics.tile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.primaryTint,
                borderRadius: PersonalShellMetrics.controlRadiusAll,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: tokens.primary, size: 20),
                child: leading!,
              ),
            ),
            const SizedBox(width: MeKitMetrics.gap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: tokens.text),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MeKitMetrics.gap),
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
              key: const ValueKey<String>('me-row-tap'),
              borderRadius: PersonalShellMetrics.controlRadiusAll,
              onTap: onTap,
              child: content,
            ),
    );
  }
}
