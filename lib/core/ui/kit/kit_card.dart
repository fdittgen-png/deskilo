// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the kit's card: the surface on the canvas, a hairline
// border, no shadow. #3674: Me's card too — the hero tone is the primary
// colour with its own text and icons; the colours come from the ambient
// scheme, which under the personal theme is the personal tokens.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import 'kit_metrics.dart';

/// How a card looks.
enum KitCardTone {
  /// The surface on the canvas, with a hairline border.
  normal,

  /// The one card a page leads with: the primary colour, no border.
  hero,
}

class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.child,
    this.tone = KitCardTone.normal,
    this.padding = const EdgeInsets.all(KitMetrics.cardPadding),
  });

  final Widget child;
  final KitCardTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hero = tone == KitCardTone.hero;
    final inside = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hero ? scheme.primary : scheme.surface,
        borderRadius: AppRadius.xlAll,
        border: hero ? null : Border.all(color: scheme.outlineVariant),
      ),
      child: hero
          ? DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onPrimary),
              child: IconTheme.merge(
                data: IconThemeData(color: scheme.onPrimary),
                child: inside,
              ),
            )
          : inside,
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
    // #3674 — a label heads what it labels, for a screen reader too.
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
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
