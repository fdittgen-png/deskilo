// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// Layout constants of [EmptyState] — pinned by test, not free-floating
/// magic numbers.
abstract final class EmptyStateMetrics {
  /// Size of the muted leading icon.
  static const double iconSize = 48;

  /// Outer padding around the whole block.
  static const double padding = 24;

  /// Gap between the icon and the title.
  static const double iconGap = 12;

  /// Gap between the title and the optional subtitle.
  static const double subtitleGap = 4;
}

/// Shared empty-state block (#209): a muted icon over a `titleMedium`
/// title and an optional `bodySmall` subtitle, centered.
///
/// Callers pass their EXISTING localized string as [title] — this widget
/// introduces no text of its own.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  /// Context icon, rendered muted ([ColorScheme.onSurfaceVariant]).
  final IconData icon;

  /// The site's localized empty-state message.
  final String title;

  /// Optional secondary line.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      // #1339 — at twice the text size this block outgrew a short
      // viewport and the Column overflowed by 224 px. It sits on 19
      // screens, so the overflow appeared wherever a list was empty and
      // the reader had large text switched on.
      //
      // Under Center's loose constraints the scroll view sizes to its
      // child, so when the content fits this renders exactly as before
      // and scrolls only when it would otherwise be clipped.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(EmptyStateMetrics.padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: EmptyStateMetrics.iconSize, color: muted),
              const SizedBox(height: EmptyStateMetrics.iconGap),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: EmptyStateMetrics.subtitleGap),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
