// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- one entry of a "To do" card: an icon tile, what to do, for
// how many, and one labelled button. The first entry's button is filled, the
// others tonal, so the screen has one filled button.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import 'kit_metrics.dart';

/// The most of a To do row's width its button takes; its label shortens
/// beyond that.
const double _buttonShare = 0.45;

class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.buttonLabel,
    required this.onPressed,
    required this.buttonKey,
    this.primary = false,
    this.alert = false,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String buttonLabel;

  /// Null while the entry waits for a read: its button is shown, disabled.
  final VoidCallback? onPressed;
  final Key buttonKey;

  /// The first entry: its button is the screen's filled one.
  final bool primary;

  /// Something failed: the tile takes the error tint.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (tileBg, tileFg) = alert
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : (scheme.primaryContainer, scheme.onPrimaryContainer);
    final label = Text(
      buttonLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final button = primary
        ? FilledButton(key: buttonKey, onPressed: onPressed, child: label)
        : FilledButton.tonal(
            key: buttonKey,
            onPressed: onPressed,
            child: label,
          );
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox.square(
            dimension: KitMetrics.tile,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: AppRadius.lgAll,
              ),
              child: Icon(icon, size: 20, color: tileFg),
            ),
          ),
          const SizedBox(width: KitMetrics.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KitMetrics.gap),
          // A long word at a large text size shortens rather than overflows:
          // the button takes at most its share of the row, and the words keep
          // the rest. Not a flex child: sharing the free space with the words
          // took half of it from them and could leave the button under 48 dp.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.hasBoundedWidth
                  ? constraints.maxWidth * _buttonShare
                  : double.infinity,
            ),
            child: button,
          ),
        ],
      ),
    );
  }
}
