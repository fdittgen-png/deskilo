// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a whole is made of, as a picture: a ring of slices and, beside it, a
// legend that says each part's amount and share — the ring is a picture of
// the legend, so nothing depends on colour alone.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_analysis.dart';

/// A distinguishable colour for part [index], drawn from the theme.
Color biPartColor(ColorScheme scheme, int index) {
  final base = HSLColor.fromColor(scheme.primary);
  final hue = (base.hue + index * 47) % 360;
  return base
      .withHue(hue)
      .withLightness(
        (scheme.brightness == Brightness.dark ? 0.62 : 0.42) +
            (index.isOdd ? 0.08 : 0),
      )
      .withSaturation(base.saturation.clamp(0.45, 0.62).toDouble())
      .toColor();
}

/// What a whole is made of: a ring of slices and, beside it, a legend that
/// says each part's amount and share — the ring is a picture of the legend.
class BiShareBreakdown extends StatelessWidget {
  const BiShareBreakdown({
    super.key,
    required this.shares,
    required this.formatValue,
    required this.formatShare,
    required this.centreLabel,
    required this.centreValue,
  });

  final List<BiShare> shares;
  final String Function(num value) formatValue;
  final String Function(double share) formatShare;

  /// The ring's centre: what the whole is ("Reserved seat-hours").
  final String centreLabel;
  final String centreValue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final colors = [
      for (var i = 0; i < shares.length; i++)
        shares[i].isOther ? scheme.outline : biPartColor(scheme, i),
    ];
    final ring = SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            key: const ValueKey('bi-donut'),
            size: const Size.square(150),
            painter: _DonutPainter(
              shares: [for (final s in shares) s.share],
              colors: colors,
              track: scheme.surfaceContainerHighest,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(centreValue, style: text.titleMedium, textAlign: TextAlign.center),
                Text(centreLabel, style: text.labelSmall, textAlign: TextAlign.center, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shares.length; i++)
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                '${shares[i].label}, ${formatShare(shares[i].share)}, ${formatValue(shares[i].value)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                    child: const SizedBox.square(dimension: 12),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      shares[i].label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatShare(shares[i].share),
                    key: ValueKey('bi-share-${shares[i].key}'),
                    style: text.labelLarge,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(formatValue(shares[i].value), style: text.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth > 420
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [ring, const SizedBox(width: AppSpacing.lg), Expanded(child: legend)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Center(child: ring), const SizedBox(height: AppSpacing.md), legend],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.shares, required this.colors, required this.track});

  final List<double> shares;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    var start = -math.pi / 2;
    const gap = 0.02;
    for (var i = 0; i < shares.length; i++) {
      final sweep = shares[i] * math.pi * 2;
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(0.001, sweep - gap),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.shares != shares || old.colors != colors;
}
