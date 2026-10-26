// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What a report visual may be, from what its figure is. A metric's unit,
// aggregation, coverage and the groupings its module answers decide which
// visual kinds, groupings, number formats, sorts and axes make sense; a
// choice outside them is refused with its reason and the visual keeps its
// previous valid binding — nothing is silently reinterpreted:
//   * a figure, a table: any metric;
//   * a line: a figure with a history (not a "today only" figure);
//   * a bar ranks groups: it needs a grouping the module answers, and its
//     quantitative axis always starts at zero;
//   * a stacked bar is a whole and its parts: only an additive figure;
//   * a percentage stays a percentage, an amount stays an amount in its
//     currency, a count stays a count;
//   * sorting by value needs groups to sort.
// Editing a visual never changes the metric's formula, its source amount or
// any document: these rules only choose how the registered figure is shown.
//
// Pure Dart.
library;

import 'bi_modules.dart';
import 'bi_report_visual.dart';
import 'kpi_descriptor.dart';

/// Why a choice was refused.
enum BiBindingRefusal {
  /// The figure is not a registered module this reader may see.
  unknownMetric,

  /// A line needs a history; this figure is today's state only.
  noHistory,

  /// A bar or a stacked bar needs a grouping this figure answers.
  noGrouping,

  /// Only an additive figure is a whole made of parts.
  notAdditive,

  /// The figure is not answered by that grouping.
  dimensionUnsupported,

  /// The number format would change the figure's unit.
  formatUnit,

  /// A value sort needs groups.
  sortNeedsGrouping,

  /// Only a line's axis may be fitted to its values.
  axisNeedsLine,

  /// A text carries no figure.
  textHasNoMetric,
}

/// The module [metricId] names, or null.
BiModule? biModuleOf(String? metricId) =>
    biModules.where((m) => m.id == metricId).firstOrNull;

/// The groupings [module] answers in a report: the dimensions its metric
/// declares that the module can actually group by.
Set<String> biDimensionsOf(BiModule module) => {
  for (final d in module.metric.dimensions)
    if (module.groupings.contains(d)) d,
};

/// The number formats that keep [module]'s unit.
Set<String> biFormatsOf(BiModule module) => {
  'auto',
  ...switch (module.metric.unit) {
    'percent' => const {'percent'},
    'currency_minor' => const {'currency'},
    _ => const {'number'},
  },
};

/// Why [type] cannot show [module]; null when it can.
BiBindingRefusal? _typeRefusal(BiVisualType type, BiModule module) =>
    switch (type) {
      BiVisualType.text => BiBindingRefusal.textHasNoMetric,
      BiVisualType.kpi || BiVisualType.table => null,
      BiVisualType.line =>
        module.metric.coverage == KpiCoverage.currentStateOnly
            ? BiBindingRefusal.noHistory
            : null,
      BiVisualType.bar =>
        biDimensionsOf(module).isEmpty ? BiBindingRefusal.noGrouping : null,
      BiVisualType.stackedBar =>
        biDimensionsOf(module).isEmpty
            ? BiBindingRefusal.noGrouping
            : module.aggregation != KpiAggregation.sum
            ? BiBindingRefusal.notAdditive
            : null,
    };

/// Why [visual] is not a valid binding; null when every part of it fits its
/// figure.
BiBindingRefusal? _visualRefusal(BiReportVisual visual) {
  if (visual.type == BiVisualType.text) return null;
  final module = biModuleOf(visual.metricId);
  if (module == null) return BiBindingRefusal.unknownMetric;
  if (_typeRefusal(visual.type, module) case final r?) return r;
  final dimension = visual.dimension;
  if (dimension != null && !biDimensionsOf(module).contains(dimension)) {
    return BiBindingRefusal.dimensionUnsupported;
  }
  if (!biFormatsOf(module).contains(visual.format ?? 'auto')) {
    return BiBindingRefusal.formatUnit;
  }
  if ((visual.sort ?? 'natural') != 'natural' && dimension == null) {
    return BiBindingRefusal.sortNeedsGrouping;
  }
  if (visual.style.axis != 'zero' && visual.type != BiVisualType.line) {
    return BiBindingRefusal.axisNeedsLine;
  }
  return null;
}

/// The outcome of a change to a visual: the changed visual, or the reason it
/// was refused (the visual is then left as it was).
class BiBinding {
  const BiBinding.ok(BiReportVisual this.visual) : refusal = null;
  const BiBinding.refused(BiBindingRefusal this.refusal) : visual = null;

  final BiReportVisual? visual;
  final BiBindingRefusal? refusal;
}

/// [next] when it is valid, else the reason.
BiBinding biChecked(BiReportVisual next) => switch (_visualRefusal(next)) {
  final r? => BiBinding.refused(r),
  null => BiBinding.ok(next),
};

/// [visual] bound to [metricId] at the version this client reads. A kind,
/// grouping, format or sort the new figure cannot keep is refused rather
/// than changed behind the person's back.
BiBinding biBindMetric(BiReportVisual visual, String metricId) {
  if (visual.type == BiVisualType.text) {
    return const BiBinding.refused(BiBindingRefusal.textHasNoMetric);
  }
  final module = biModuleOf(metricId);
  if (module == null) {
    return const BiBinding.refused(BiBindingRefusal.unknownMetric);
  }
  return biChecked(visual.withMetric(metricId, module.metric.version));
}

/// [visual] shown as [type]; a bar or stacked bar takes the figure's first
/// grouping when it had none, a figure or a line drops a fitted axis it
/// cannot keep only when that is the one obstacle — otherwise refused.
BiBinding biSetType(BiReportVisual visual, BiVisualType type) {
  if (visual.type == BiVisualType.text || type == BiVisualType.text) {
    return const BiBinding.refused(BiBindingRefusal.textHasNoMetric);
  }
  final module = biModuleOf(visual.metricId);
  if (module == null) {
    return const BiBinding.refused(BiBindingRefusal.unknownMetric);
  }
  final grouped = type == BiVisualType.bar || type == BiVisualType.stackedBar;
  final dimension = grouped && visual.dimension == null
      ? biDimensionsOf(module).firstOrNull
      : null;
  return biChecked(
    visual
        .copyWith(
          type: type,
          style: type == BiVisualType.line
              ? null
              : visual.style.withValue('axis', 'zero'),
        )
        .withDimension(dimension ?? visual.dimension),
  );
}

/// [visual] grouped by [dimension] (null: not grouped). A bar keeps a
/// grouping; a value sort without groups is refused.
BiBinding biSetDimension(BiReportVisual visual, String? dimension) {
  final grouped =
      visual.type == BiVisualType.bar || visual.type == BiVisualType.stackedBar;
  if (dimension == null && grouped) {
    return const BiBinding.refused(BiBindingRefusal.noGrouping);
  }
  return biChecked(
    dimension == null
        ? visual.withDimension(null)
        : visual.withDimension(dimension),
  );
}

/// [visual] with the number format [format] (`auto` clears it).
BiBinding biSetFormat(BiReportVisual visual, String format) => biChecked(
  format == 'auto' ? visual.withFormat(null) : visual.withFormat(format),
);

/// [visual] sorted by [sort].
BiBinding biSetSort(BiReportVisual visual, String sort) =>
    biChecked(visual.withSort(sort));

/// [visual] with its style's [key] set to [value].
BiBinding biSetStyle(BiReportVisual visual, String key, Object? value) {
  final style = visual.style.withValue(key, value);
  return biChecked(visual.copyWith(style: style));
}
