// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pictures of the Business analytics dashboard: the evolution over the
// past periods with its projection, how now compares with the past, and
// what a whole is made of.
//
// Every picture is made from the rows [bi_analysis.dart] computes and
// carries the same figures as text — a readout under the evolution, the
// value on every bar, a legend with the amount and the share beside every
// slice — so nothing depends on colour or on seeing the drawing, and a
// screen reader gets the same sentences. A gap in the data is a gap in the
// picture, never a zero; the projection is dashed and its range shaded, so
// an estimate never looks like a measurement.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/status_colors.dart';
import '../../domain/bi_analysis.dart';
import '../../domain/bi_query.dart';

/// "▲ +12.5 %", "▼ −3 %", "● flat": the change as an arrow, a colour and
/// words — never colour alone.
class BiDeltaChip extends StatelessWidget {
  const BiDeltaChip({
    super.key,
    required this.direction,
    required this.label,
    this.semanticsPrefix,
  });

  final BiDirection direction;
  final String label;
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (direction) {
      BiDirection.up => (
        Icons.arrow_upward_rounded,
        AppStatusColors.successTextOf(scheme.brightness),
      ),
      BiDirection.down => (Icons.arrow_downward_rounded, scheme.error),
      BiDirection.flat => (Icons.trending_flat_rounded, scheme.onSurfaceVariant),
      BiDirection.unknown => (Icons.remove_rounded, scheme.onSurfaceVariant),
    };
    return Semantics(
      label: [?semanticsPrefix, label].join(' '),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The evolution: the figure over the past periods as a line, the
/// projection beyond the current period dashed with its likely range
/// shaded. Tapping (or hovering) a point reads it out underneath.
class BiEvolutionChart extends StatefulWidget {
  const BiEvolutionChart({
    super.key,
    required this.series,
    required this.forecast,
    required this.format,
    required this.periodLabel,
    required this.shortLabel,
    required this.projectedLabel,
    required this.noDataLabel,
    required this.partialLabel,
  });

  final BiSeries series;
  final BiForecast? forecast;
  final String Function(num value) format;

  /// "October 2026".
  final String Function(BiPeriod period) periodLabel;

  /// The axis label: "oct.", "Q3", "2026".
  final String Function(BiPeriod period) shortLabel;

  /// "Estimate" — appended to a projected point's readout.
  final String projectedLabel;

  /// "no data" — the readout of a gap.
  final String noDataLabel;

  /// "running" — the readout of a period that is not over.
  final String partialLabel;

  @override
  State<BiEvolutionChart> createState() => _BiEvolutionChartState();
}

class _BiEvolutionChartState extends State<BiEvolutionChart> {
  int? _selected;

  List<({BiPeriod period, num? value, bool partial, bool projected})> get _all =>
      [
        for (final p in widget.series.points)
          (period: p.period, value: p.value, partial: p.partial, projected: false),
        for (final f in widget.forecast?.points ?? const <BiForecastPoint>[])
          (period: f.period, value: f.value, partial: false, projected: true),
      ];

  String _readout(int i) {
    final p = _all[i];
    final what = p.value == null ? widget.noDataLabel : widget.format(p.value!);
    final tag = p.projected
        ? ' · ${widget.projectedLabel}'
        : p.partial
        ? ' · ${widget.partialLabel}'
        : '';
    return '${widget.periodLabel(p.period)}: $what$tag';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final all = _all;
    final current = widget.series.points.length - 1;
    final shown = _selected ?? current;
    final summary = [for (var i = 0; i < all.length; i++) _readout(i)].join('; ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _readout(shown.clamp(0, all.length - 1)),
          key: const ValueKey('bi-evolution-readout'),
          style: text.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: summary,
          excludeSemantics: true,
          child: LayoutBuilder(
            builder: (context, box) {
              void pick(Offset at) {
                final i = _indexAt(at.dx, box.maxWidth, all.length);
                if (i != _selected) setState(() => _selected = i);
              }

              return MouseRegion(
                onHover: (e) => pick(e.localPosition),
                child: GestureDetector(
                  key: const ValueKey('bi-evolution'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => pick(d.localPosition),
                  onHorizontalDragUpdate: (d) => pick(d.localPosition),
                  child: CustomPaint(
                    size: Size(box.maxWidth, 180),
                    painter: _EvolutionPainter(
                      points: all,
                      currentIndex: current,
                      selected: shown,
                      forecast: widget.forecast,
                      historyLength: widget.series.points.length,
                      format: widget.format,
                      shortLabel: widget.shortLabel,
                      line: scheme.primary,
                      projection: scheme.tertiary,
                      grid: scheme.outlineVariant,
                      label: text.labelSmall ?? const TextStyle(),
                      labelColor: scheme.onSurfaceVariant,
                      surface: scheme.surface,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _left = 52.0;
  static const _right = 8.0;

  int _indexAt(double dx, double width, int count) {
    if (count <= 1) return 0;
    final plot = width - _left - _right;
    final step = plot / (count - 1);
    return ((dx - _left) / step).round().clamp(0, count - 1);
  }
}

class _EvolutionPainter extends CustomPainter {
  _EvolutionPainter({
    required this.points,
    required this.currentIndex,
    required this.selected,
    required this.forecast,
    required this.historyLength,
    required this.format,
    required this.shortLabel,
    required this.line,
    required this.projection,
    required this.grid,
    required this.label,
    required this.labelColor,
    required this.surface,
  });

  final List<({BiPeriod period, num? value, bool partial, bool projected})>
  points;
  final int currentIndex;
  final int selected;
  final BiForecast? forecast;
  final int historyLength;
  final String Function(num) format;
  final String Function(BiPeriod) shortLabel;
  final Color line, projection, grid, labelColor, surface;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = _BiEvolutionChartState._left;
    const right = _BiEvolutionChartState._right;
    const top = 8.0, bottom = 22.0;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = <double>[
      for (final p in points)
        if (p.value != null) p.value!.toDouble(),
      for (final f in forecast?.points ?? const <BiForecastPoint>[]) ...[f.low, f.high],
    ];
    if (values.isEmpty || points.length < 2) return;
    var lo = math.min(0.0, values.reduce(math.min));
    var hi = values.reduce(math.max);
    if (hi <= lo) hi = lo + 1;
    final pad = (hi - lo) * 0.08;
    hi += pad;
    double x(int i) => plot.left + plot.width * i / (points.length - 1);
    double y(double v) => plot.bottom - plot.height * (v - lo) / (hi - lo);

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
    for (var t = 0; t <= 2; t++) {
      final v = lo + (hi - lo) * t / 2;
      final py = y(v);
      canvas.drawLine(Offset(plot.left, py), Offset(plot.right, py), gridPaint);
      tp
        ..text = TextSpan(text: format(v), style: label.copyWith(color: labelColor))
        ..layout(maxWidth: left - 6);
      tp.paint(canvas, Offset(left - 6 - tp.width, py - tp.height / 2));
    }
    // The axis: every period's label that fits, the current one always.
    final every = math.max(1, (points.length / 7).ceil());
    for (var i = 0; i < points.length; i++) {
      if (i % every != 0 && i != currentIndex) continue;
      tp
        ..text = TextSpan(
          text: shortLabel(points[i].period),
          style: label.copyWith(color: labelColor),
        )
        ..layout(maxWidth: 48);
      tp.paint(canvas, Offset(x(i) - tp.width / 2, plot.bottom + 4));
    }

    // The projection's likely range, then its line.
    final fp = forecast?.points ?? const <BiForecastPoint>[];
    if (fp.isNotEmpty) {
      final anchor = points[currentIndex].value;
      final band = Path();
      final startY = anchor == null ? y(fp.first.value) : y(anchor.toDouble());
      band.moveTo(x(currentIndex), startY);
      for (var k = 0; k < fp.length; k++) {
        band.lineTo(x(currentIndex + 1 + k), y(fp[k].high));
      }
      for (var k = fp.length - 1; k >= 0; k--) {
        band.lineTo(x(currentIndex + 1 + k), y(fp[k].low));
      }
      band.close();
      canvas.drawPath(band, Paint()..color = projection.withValues(alpha: 0.16));
      final dashed = Path()..moveTo(x(currentIndex), startY);
      for (var k = 0; k < fp.length; k++) {
        dashed.lineTo(x(currentIndex + 1 + k), y(fp[k].value));
      }
      _dash(canvas, dashed, Paint()
        ..color = projection
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      for (var k = 0; k < fp.length; k++) {
        canvas.drawCircle(
          Offset(x(currentIndex + 1 + k), y(fp[k].value)),
          3.5,
          Paint()..color = projection,
        );
      }
    }

    // The past, with a break at every gap.
    final linePaint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    Path? run;
    for (var i = 0; i < historyLength; i++) {
      final v = points[i].value;
      if (v == null) {
        if (run != null) canvas.drawPath(run, linePaint);
        run = null;
        continue;
      }
      final o = Offset(x(i), y(v.toDouble()));
      if (run == null) {
        run = Path()..moveTo(o.dx, o.dy);
      } else {
        run.lineTo(o.dx, o.dy);
      }
    }
    if (run != null) canvas.drawPath(run, linePaint);
    for (var i = 0; i < historyLength; i++) {
      final v = points[i].value;
      if (v == null) continue;
      final o = Offset(x(i), y(v.toDouble()));
      final hollow = points[i].partial;
      canvas.drawCircle(o, i == currentIndex ? 5.5 : 3.5, Paint()..color = hollow ? surface : line);
      if (hollow) {
        canvas.drawCircle(
          o,
          i == currentIndex ? 5.5 : 3.5,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    // The selected period.
    final sv = points[selected].value;
    final sx = x(selected);
    canvas.drawLine(
      Offset(sx, plot.top),
      Offset(sx, plot.bottom),
      Paint()
        ..color = labelColor.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    if (sv != null) {
      canvas.drawCircle(
        Offset(sx, y(sv.toDouble())),
        7,
        Paint()
          ..color = (points[selected].projected ? projection : line).withValues(alpha: 0.25),
      );
    }
  }

  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 7, metric.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EvolutionPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.forecast != forecast ||
      old.line != line;
}

/// How now compares with the past: one bar for the current period, the
/// one before it and the same one a year ago, each with its value and, for
/// the past ones, the change that led to now.
class BiCompareBars extends StatelessWidget {
  const BiCompareBars({
    super.key,
    required this.bars,
    required this.format,
    required this.periodLabel,
    required this.kindLabel,
    required this.changeLabel,
    required this.direction,
    required this.partialLabel,
    required this.noDataLabel,
  });

  final List<BiComparisonBar> bars;
  final String Function(num value) format;
  final String Function(BiPeriod period) periodLabel;
  final String Function(BiBarKind kind) kindLabel;

  /// The change from [bar] to the current period, or null for the current.
  final String? Function(BiComparisonBar bar) changeLabel;
  final BiDirection Function(BiComparisonBar bar) direction;
  final String partialLabel;
  final String noDataLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final top = bars
        .map((b) => b.value?.abs().toDouble() ?? 0)
        .fold<double>(0, math.max);
    return Column(
      key: const ValueKey('bi-compare'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final bar in bars)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Semantics(
              container: true,
              excludeSemantics: true,
              label: [
                kindLabel(bar.kind),
                periodLabel(bar.period),
                bar.value == null ? noDataLabel : format(bar.value!),
                if (bar.partial) partialLabel,
                ?changeLabel(bar),
              ].join(', '),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${kindLabel(bar.kind)} · ${periodLabel(bar.period)}',
                        style: text.labelLarge,
                      ),
                      Text(
                        bar.value == null
                            ? noDataLabel
                            : '${format(bar.value!)}${bar.partial ? ' · $partialLabel' : ''}',
                        key: ValueKey('bi-compare-${bar.kind.name}'),
                      ),
                      if (changeLabel(bar) case final c?)
                        BiDeltaChip(direction: direction(bar), label: c),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: SizedBox(
                      height: 14,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final f = bar.value == null || top == 0
                              ? 0.0
                              : (bar.value!.abs() / top).clamp(0.0, 1.0);
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: ColoredBox(color: scheme.surfaceContainerHighest),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: box.maxWidth * f,
                                child: ColoredBox(
                                  color: bar.kind == BiBarKind.current
                                      ? scheme.primary
                                      : scheme.outline,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
