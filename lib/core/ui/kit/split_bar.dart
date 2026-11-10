// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- one bar in parts, each as wide as its share, and the legend
// lines that say each part in words (and filter by it). The bar is a
// picture of the legend: assistive technology reads the legend, not the bar.
import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import 'kit_metrics.dart';

/// One part of a [SplitBar]: its share and its colour.
typedef SplitPart = ({int weight, Color color});

class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.parts});

  /// The parts in order; a part of weight 0 is not drawn.
  final List<SplitPart> parts;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final p in parts)
        if (p.weight > 0) p,
    ];
    return ExcludeSemantics(
      child: SizedBox(
        height: KitMetrics.barHeight,
        child: Row(
          spacing: 3,
          // Each part fills the bar's height: a box without a child would
          // otherwise shrink to nothing.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in shown)
              Expanded(
                flex: p.weight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: KitMetrics.barMinPart,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.color,
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One legend line: the part's colour, its name and count, its amount; a
/// toggle that filters by it.
class LegendToggle extends StatelessWidget {
  const LegendToggle({
    super.key,
    required this.color,
    required this.label,
    required this.caption,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final String caption;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: selected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KitMetrics.minTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: KitMetrics.dot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                  ),
                  const SizedBox(width: KitMetrics.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label),
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
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
