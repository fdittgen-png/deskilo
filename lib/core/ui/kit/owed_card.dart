// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the card that answers the screen's first question: how much
// is owed, and in which state. One headline total and one bar per currency
// (never a sum across currencies), the legend lines that filter, and the
// month's two figures under a hairline.
import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';
import 'kit_card.dart';
import 'kit_metrics.dart';
import 'split_bar.dart';

/// What one currency owes: its total in words and figures, its bar.
typedef OwedBlock = ({String total, List<SplitPart> parts});

/// One of the month's figures: what it is, and its value (one line per
/// currency).
typedef OwedFigure = ({String label, List<String> values});

class OwedCard extends StatelessWidget {
  const OwedCard({
    super.key,
    required this.label,
    required this.blocks,
    required this.legend,
    required this.figures,
  });

  final String label;

  /// One block per currency, in the order they are shown.
  final List<OwedBlock> blocks;

  /// The legend lines ([LegendToggle]s); a bucket with nothing is left out.
  final List<Widget> legend;

  /// The month's figures, side by side under a hairline.
  final List<OwedFigure> figures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = theme.textTheme.headlineMedium?.emphasised.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return KitCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: KitMetrics.gap,
        children: [
          KitLabel(label),
          for (final (i, b) in blocks.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Text(b.total, style: total),
            if (b.parts.isNotEmpty) SplitBar(parts: b.parts),
          ],
          ...legend,
          if (figures.isNotEmpty) ...[
            const Divider(height: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: KitMetrics.gap,
              children: [
                for (final f in figures)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        for (final v in f.values)
                          Text(
                            v,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
