// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the kit's card: the surface on the canvas, a hairline
// border, no shadow.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import 'kit_metrics.dart';

class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KitMetrics.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A label above a card's content, in capitals of the label style.
class KitLabel extends StatelessWidget {
  const KitLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// One calm line with a check: "You are all caught up." and the like.
class QuietLine extends StatelessWidget {
  const QuietLine(this.text, {super.key, this.icon = Icons.check});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: KitMetrics.gap),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
