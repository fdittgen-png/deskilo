// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The charts of a report visual, each with its values written out:
//   * a bar ranks groups from a zero baseline, every bar labelled with its
//     value, the scale stated (a percentage on 0–100 %, never a normalised
//     bar that could pass for one);
//   * a stacked bar is a whole and its labelled parts, and only of a
//     complete positive composition — a signed figure is a table instead;
//   * a line is a qualified trend: no history says so in a line, one known
//     period is a point, never a trend; an axis that does not start at zero
//     says so;
//   * every chart has its table, so colour is never the only signal and a
//     screen reader reads the same values.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_analysis.dart';
import '../../domain/bi_modules.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_report_definition.dart';
import '../../domain/bi_result.dart';
import '../../providers/bi_providers.dart';
import '../widgets/bi_module_section.dart' show BiModuleView;
import '../widgets/bi_toolbar.dart' show biPeriodLabel;

/// The height of a bar and of the line's plot.
const _barHeight = 14.0, _lineHeight = 96.0;

/// The same values as a table, folded under a chart.
class BiAsTable extends StatelessWidget {
  const BiAsTable({super.key, required this.visualId, required this.child});

  final String visualId;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('bi-visual-table-$visualId'),
    tilePadding: EdgeInsets.zero,
    title: Text(context.l10n.biEditorAsTable),
    children: [child],
  );
}

/// The colours a palette allows, from the theme's own tokens.
List<Color> _palette(ColorScheme cs, String palette) => switch (palette) {
  'contrast' => [cs.onSurface, cs.primary, cs.error, cs.tertiary],
  'mono' => [
    for (final a in const [1.0, 0.75, 0.5, 0.3])
      cs.primary.withValues(alpha: a),
  ],
  _ => [cs.primary, cs.tertiary, cs.secondary, cs.outline],
};

class BiBars extends StatelessWidget {
  const BiBars({
    super.key,
    required this.visual,
    required this.rows,
    required this.percent,
    required this.label,
    required this.valueOf,
    required this.text,
    required this.onPick,
  });

  final BiReportVisual visual;
  final List<BiRow> rows;
  final bool percent;
  final String Function(BiRow) label;
  final num? Function(BiRow) valueOf;
  final String Function(BiRow) text;
  final ValueChanged<BiRow>? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colours = _palette(theme.colorScheme, visual.style.palette);
    final known = [
      for (final r in rows)
        if (!r.current.unknown && (valueOf(r) ?? 0) > 0) r,
    ];
    if (known.isEmpty) {
      return Text(
        l10n.overviewUnavailable,
        key: ValueKey('bi-visual-unavailable-${visual.id}'),
      );
    }
    if (visual.type == BiVisualType.stackedBar) {
      // A whole and its parts only when every part is a positive amount: a
      // signed figure is no composition, and its table says it exactly.
      if (rows.any((r) => !r.current.unknown && (valueOf(r) ?? 0) < 0)) {
        return Text(
          l10n.biEditorNotComposition,
          key: ValueKey('bi-visual-not-composition-${visual.id}'),
        );
      }
      final total = known.fold<num>(0, (s, r) => s + valueOf(r)!);
      final share = NumberFormat.percentPattern(
        Localizations.localeOf(context).toString(),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                for (final (i, r) in known.indexed)
                  Expanded(
                    flex: math.max(1, (valueOf(r)! / total * 1000).round()),
                    child: ColoredBox(color: colours[i % colours.length]),
                  ),
              ],
            ),
          ),
          if (visual.style.legend)
            for (final (i, r) in known.indexed)
              _Legend(
                key: ValueKey('bi-bar-${visual.id}-${r.key}'),
                colour: colours[i % colours.length],
                text:
                    '${label(r)}: ${text(r)} (${share.format(valueOf(r)! / total)})',
                onTap: onPick == null ? null : () => onPick!(r),
              ),
        ],
      );
    }
    final max = percent ? 1.0 : known.map((r) => valueOf(r)!).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          InkWell(
            key: ValueKey('bi-bar-${visual.id}-${r.key}'),
            onTap: onPick == null ? null : () => onPick!(r),
            child: Container(
              // A pickable row is a full touch target.
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visual.style.labels ? '${label(r)} · ${text(r)}' : label(r),
                  ),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: r.current.unknown
                        ? 0
                        : ((valueOf(r) ?? 0) / max).clamp(0.0, 1.0).toDouble(),
                    child: Container(height: _barHeight, color: colours.first),
                  ),
                ],
              ),
            ),
          ),
        Text(
          percent
              ? l10n.biEditorScalePercent
              : l10n.biEditorScaleMax(
                  text(known.firstWhere((r) => valueOf(r) == max)),
                ),
          key: ValueKey('bi-visual-scale-${visual.id}'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    super.key,
    required this.colour,
    required this.text,
    required this.onTap,
  });

  final Color colour;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('${(key as ValueKey<String>?)?.value}-pick'),
    onTap: onTap,
    child: Container(
      // A pickable row is a full touch target.
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox.square(
            dimension: _barHeight,
            child: ColoredBox(color: colour),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

/// A qualified trend of the figure over the periods before [end].
class BiLineBody extends ConsumerWidget {
  const BiLineBody({
    super.key,
    required this.workspaceId,
    required this.module,
    required this.view,
    required this.visual,
    required this.query,
    required this.end,
  });

  final String workspaceId;
  final BiModule module;
  final BiModuleView view;
  final BiReportVisual visual;

  /// The report's period, ungrouped: its answer names the currency.
  final BiQueryContext query;
  final BiPeriod end;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final grain = query.grain;
    final answer = ref.watch(
      biModuleSeriesProvider(
        workspaceId,
        module.id,
        grain,
        end,
        biSeriesLength(grain),
      ),
    );
    final currency = ref
        .watch(biModuleResultProvider(workspaceId, module.id, query))
        // A current answer only: a refusal never shows what came before.
        .asData
        ?.value
        .currency;
    final series = switch (answer) {
      AsyncData(:final value) => value,
      AsyncError() => null,
      _ => const BiSeries([]),
    };
    if (answer.isLoading) return const LinearProgressIndicator();
    final known = [
      for (final p in series?.points ?? const <BiSeriesPoint>[])
        if (p.known) p,
    ];
    String value(BiSeriesPoint p) => view.value(p.value, locale, currency);
    String line(BiSeriesPoint p) =>
        '${biPeriodLabel(p.period, l10n, locale)}: ${value(p)}';
    if (known.isEmpty) {
      return Text(
        l10n.biEditorNoHistory,
        key: ValueKey('bi-visual-no-history-${visual.id}'),
      );
    }
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final p in known) Text(line(p))],
    );
    if (known.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.biEditorOnePoint,
            key: ValueKey('bi-visual-one-point-${visual.id}'),
          ),
          table,
        ],
      );
    }
    final values = [for (final p in known) p.value!.toDouble()];
    final fit = visual.style.axis == 'fit';
    final low = fit
        ? values.reduce(math.min)
        : math.min(0.0, values.reduce(math.min));
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: known.map(line).join('; '),
          excludeSemantics: true,
          child: SizedBox(
            height: _lineHeight,
            width: double.infinity,
            child: CustomPaint(
              key: ValueKey('bi-visual-line-${visual.id}'),
              painter: _LinePainter(
                points: series!.points,
                low: low,
                colour: _palette(cs, visual.style.palette).first,
                axis: cs.outline,
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                biPeriodLabel(series.points.first.period, l10n, locale),
              ),
            ),
            Text(biPeriodLabel(series.points.last.period, l10n, locale)),
          ],
        ),
        if (fit && low > 0)
          Text(
            l10n.biEditorAxisCut(view.value(low, locale, currency)),
            key: ValueKey('bi-visual-axis-cut-${visual.id}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        BiAsTable(visualId: visual.id, child: table),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.low,
    required this.colour,
    required this.axis,
  });

  final List<BiSeriesPoint> points;
  final double low;
  final Color colour;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final p in points)
        if (p.value != null) p.value!.toDouble(),
    ];
    var high = values.reduce(math.max);
    if (high <= low) high = low + 1;
    double x(int i) => size.width * i / math.max(1, points.length - 1);
    double y(double v) => size.height - (v - low) / (high - low) * size.height;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()..color = axis,
    );
    final stroke = Paint()
      ..color = colour
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    Offset? last;
    for (final (i, p) in points.indexed) {
      final v = p.value;
      if (v == null) {
        // A period the data does not know is a gap, never a zero.
        last = null;
        continue;
      }
      final at = Offset(x(i), y(v.toDouble()));
      if (last != null) canvas.drawLine(last, at, stroke);
      canvas.drawCircle(at, 3, Paint()..color = colour);
      last = at;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.low != low || old.colour != colour;
}
