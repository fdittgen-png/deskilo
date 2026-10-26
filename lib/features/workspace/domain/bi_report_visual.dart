// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2579 — the parts of an analytical report (a v2 saved view) that sit
// inside a page: typed filters, the grid position and the visual itself.
// Questions, never answers: no figures, SQL, formulas, links or HTML. The
// same shape is checked by `bi_definition_valid` on the server.
//
// Pure Dart.
library;

import '../../../core/data/json_reader.dart';
import 'bi_modules.dart';
import 'kpi_contract.dart';

/// The visual kinds a report may hold.
enum BiVisualType {
  kpi,
  line,
  bar,
  stackedBar,
  table,
  text;

  static BiVisualType? fromWire(Object? v) =>
      values.where((t) => t.name == v).firstOrNull;
}

/// The dimensions a report filter or a visual's grouping may name: those the
/// registered metrics declare. A name, never an id. `bi_report_dimensions()`
/// is the server's copy.
Set<String> get _reportDimensions => {
  for (final m in biModules) ...m.metric.dimensions,
};

/// Whether every filter in [lower] only narrows [higher]. Filters are
/// conjunctive, so a lower level can never widen a higher one; a positive
/// filter (`eq`, `in`) that names a value a higher filter of the same
/// dimension does not admit could only mean "instead of", and is refused
/// rather than read as an override.
bool biFiltersNarrow(List<BiReportFilter> higher, List<BiReportFilter> lower) {
  for (final l in lower.where((f) => f.positive)) {
    for (final h in higher.where((h) => h.dimension == l.dimension)) {
      final admits = h.positive
          ? h.values.containsAll(l.values)
          : !l.values.contains(h.value);
      if (!admits) return false;
    }
  }
  return true;
}

/// A registered name: a metric or a dimension.
final _reportName = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$');

/// A page or visual id.
final biReportId = RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$');

/// [r] as a reader, or null when it is not an object.
JsonReader? biReportReader(Object? raw) {
  try {
    return JsonReader.of(raw, context: 'bi report');
  } on JsonShapeException {
    return null;
  }
}

/// Whether [r] carries no key outside [allowed].
bool biReportOnly(JsonReader r, Set<String> allowed) =>
    r.json.keys.every(allowed.contains);

/// The filters in [raw] (absent means none), or null when any is invalid.
List<BiReportFilter>? biReportFilters(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List || raw.length > BiReportFilter.maxPerLevel) return null;
  final out = <BiReportFilter>[];
  for (final r in raw) {
    final f = BiReportFilter.fromJson(r);
    if (f == null) return null;
    out.add(f);
  }
  return out;
}

/// A typed filter `{dimension, operator, value}`.
class BiReportFilter {
  const BiReportFilter(this.dimension, this.operator, this.value);

  final String dimension;
  final String operator;
  final String value;

  static const operators = {'eq', 'neq', 'in'};
  static const maxPerLevel = 12;

  /// `eq` and `in` admit only their values; `neq` admits all but its one.
  bool get positive => operator != 'neq';

  /// The values named: an `in` lists them separated by commas.
  Set<String> get values => operator == 'in' ? value.split(',').toSet() : {value};

  Map<String, Object> toJson() => {
    'dimension': dimension,
    'operator': operator,
    'value': value,
  };

  static BiReportFilter? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null || !biReportOnly(r, const {'dimension', 'operator', 'value'})) {
      return null;
    }
    final d = r.raw('dimension'), o = r.raw('operator'), v = r.raw('value');
    if (d is! String || !_reportDimensions.contains(d)) return null;
    if (o is! String || !operators.contains(o)) return null;
    if (v is! String || v.length > 64) return null;
    return BiReportFilter(d, o, v);
  }
}

/// Where a visual sits in a page: the discrete responsive grid (12 columns
/// wide, 4 medium, 1 compact) clamps [span]; [order] is the reading order.
class BiVisualLayout {
  const BiVisualLayout({required this.order, this.span = 6, this.height = 2});

  final int order;
  final int span;
  final int height;

  static const maxSpan = 12;
  static const maxHeight = 12;
  static const maxOrder = 255;

  /// Where a new visual of [type] sits at [order]: a figure is a quarter of
  /// the wide grid on one row, a text a whole row, a chart or a table half
  /// of it on three rows.
  factory BiVisualLayout.defaultFor(BiVisualType type, int order) =>
      switch (type) {
        BiVisualType.kpi => BiVisualLayout(order: order, span: 3, height: 1),
        BiVisualType.text => BiVisualLayout(
          order: order,
          span: maxSpan,
          height: 1,
        ),
        _ => BiVisualLayout(order: order, height: 3),
      };

  BiVisualLayout copyWith({int? order, int? span, int? height}) =>
      BiVisualLayout(
        order: order ?? this.order,
        span: span ?? this.span,
        height: height ?? this.height,
      );

  Map<String, Object> toJson() => {
    'order': order,
    'span': span,
    'height': height,
  };

  static BiVisualLayout? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null || !biReportOnly(r, const {'order', 'span', 'height'})) {
      return null;
    }
    final o = r.raw('order'), s = r.raw('span'), h = r.raw('height');
    if (o is! int || s is! int || h is! int) return null;
    if (o < 0 || o > maxOrder || s < 1 || s > maxSpan) return null;
    if (h < 1 || h > maxHeight) return null;
    return BiVisualLayout(order: o, span: s, height: h);
  }
}

/// How a visual presents its figure: a heading and a description of its
/// own, its legend and value labels, a permitted palette, the axis of a line
/// and whether the source note shows. Presentation only — no formula, no
/// figure, no link: changing it never asks the server anything again. A key
/// left at its default is not written, so a visual nobody styled is stored
/// as it always was.
class BiVisualStyle {
  const BiVisualStyle({
    this.title,
    this.description,
    this.legend = true,
    this.labels = true,
    this.palette = 'standard',
    this.axis = 'zero',
    this.note = true,
  });

  /// The visible heading; null shows the figure's own name.
  final String? title;
  final String? description;
  final bool legend;

  /// Values written beside their marks, so colour is never the only sign.
  final bool labels;

  /// One of [palettes]: the app's tokens, a high-contrast set or one hue.
  final String palette;

  /// `zero` (the axis starts at zero) or `fit` (a line's axis fits its
  /// values, and says it is cut). A bar always starts at zero.
  final String axis;

  /// Whether the figure's source and basis are written under it.
  final bool note;

  static const palettes = {'standard', 'contrast', 'mono'};
  static const axes = {'zero', 'fit'};
  static const maxTitle = 80;
  static const maxDescription = 200;
  static const _keys = {
    'title',
    'description',
    'legend',
    'labels',
    'palette',
    'axis',
    'note',
  };

  bool get isDefault => toJson().isEmpty;

  /// This style with [key] set to [value] (null or an empty text clears
  /// it); itself when that would not be a valid style.
  BiVisualStyle withValue(String key, Object? value) {
    final json = <String, Object?>{...toJson(), key: value}
      ..removeWhere((_, v) => v == null || v == '');
    return fromJson(json) ?? this;
  }

  Map<String, Object> toJson() => {
    'title': ?title,
    'description': ?description,
    if (!legend) 'legend': false,
    if (!labels) 'labels': false,
    if (palette != 'standard') 'palette': palette,
    if (axis != 'zero') 'axis': axis,
    if (!note) 'note': false,
  };

  /// Absent, or plain text of 1 to [max] characters on one line.
  static bool _line(Object? v, int max) =>
      v == null ||
      (v is String && v.isNotEmpty && v.length <= max && !_control.hasMatch(v));
  static final _control = RegExp(r'[\x00-\x1F\x7F]');

  static BiVisualStyle? fromJson(Object? raw) {
    if (raw == null) return const BiVisualStyle();
    final r = biReportReader(raw);
    if (r == null || !biReportOnly(r, _keys)) return null;
    final t = r.raw('title'), d = r.raw('description');
    final legend = r.raw('legend') ?? true, labels = r.raw('labels') ?? true;
    final palette = r.raw('palette') ?? 'standard';
    final axis = r.raw('axis') ?? 'zero', note = r.raw('note') ?? true;
    if (!_line(t, maxTitle) || !_line(d, maxDescription)) return null;
    if (legend is! bool || labels is! bool || note is! bool) return null;
    if (!palettes.contains(palette) || !axes.contains(axis)) return null;
    return BiVisualStyle(
      title: t as String?,
      description: d as String?,
      legend: legend,
      labels: labels,
      palette: palette as String,
      axis: axis as String,
      note: note,
    );
  }
}

class BiReportVisual {
  const BiReportVisual({
    required this.id,
    required this.type,
    this.metricId,
    this.metricVersion = 1,
    this.dimension,
    this.filters = const [],
    this.sort,
    this.format,
    required this.layout,
    this.interaction = 'filter',
    this.drill,
    this.text,
    this.style = const BiVisualStyle(),
  });

  /// A figure card of [metricId], bound to the version of the metric this
  /// client reads, so a later version is recognised as another figure.
  factory BiReportVisual.kpi({
    required String id,
    required String metricId,
    required BiVisualLayout layout,
  }) => BiReportVisual(
    id: id,
    type: BiVisualType.kpi,
    metricId: metricId,
    metricVersion: kpiDefinitionOf(metricId)?.version ?? 1,
    layout: layout,
  );

  final String id;
  final BiVisualType type;

  /// A registered module id; null only for a [BiVisualType.text].
  final String? metricId;
  final int metricVersion;
  final String? dimension;
  final List<BiReportFilter> filters;
  final String? sort;
  final String? format;
  final BiVisualLayout layout;

  /// `filter` (a selection narrows the other visuals) or `none`.
  final String interaction;

  /// Absent: the figure's own registered source is offered; [noDrill]: no
  /// source is offered from this visual.
  final String? drill;

  /// Plain content of a text visual, shown escaped.
  final String? text;

  /// How the figure is presented; never what it is.
  final BiVisualStyle style;

  static const maxText = 500;
  static const sorts = {'natural', 'value_desc', 'value_asc'};
  static const formats = {'auto', 'number', 'percent', 'currency'};
  static const interactions = {'filter', 'none'};

  /// The stored [drill] of a visual that offers no source.
  static const noDrill = 'none';
  static const _keys = {
    'id',
    'type',
    'metricId',
    'metricVersion',
    'dimension',
    'filters',
    'sort',
    'format',
    'layout',
    'interaction',
    'drill',
    'text',
    'style',
  };

  /// This visual with the presentation parts named replaced.
  BiReportVisual copyWith({
    String? id,
    BiVisualType? type,
    BiVisualLayout? layout,
    String? interaction,
    String? text,
    BiVisualStyle? style,
  }) => BiReportVisual(
    id: id ?? this.id,
    type: type ?? this.type,
    metricId: metricId,
    metricVersion: metricVersion,
    dimension: dimension,
    filters: filters,
    sort: sort,
    format: format,
    layout: layout ?? this.layout,
    interaction: interaction ?? this.interaction,
    drill: drill,
    text: text ?? this.text,
    style: style ?? this.style,
  );

  /// Bound to [id] at [version] of its metric.
  BiReportVisual withMetric(String id, int version) =>
      _merged({'metricId': id, 'metricVersion': version});

  /// Grouped by [value] (null: not grouped).
  BiReportVisual withDimension(String? value) => _merged({'dimension': value});

  /// With the number format [value] (null: the figure's own).
  BiReportVisual withFormat(String? value) => _merged({'format': value});

  /// Sorted by [value].
  BiReportVisual withSort(String value) => _merged({'sort': value});

  /// Limited by its own [value] filters (empty: none of its own).
  BiReportVisual withFilters(List<BiReportFilter> value) =>
      _merged({'filters': [for (final f in value) f.toJson()]});

  /// Offering its figure's source ([on]) or not.
  BiReportVisual withDrill({required bool on}) =>
      _merged({'drill': on ? null : noDrill});

  /// Whether this visual offers its figure's registered source.
  bool get drills => drill != noDrill;

  /// This visual with [changes] merged into its stored form (a null clears
  /// that part); itself when the result would not be a valid visual.
  BiReportVisual _merged(Map<String, Object?> changes) =>
      fromJson({...toJson(), ...changes}..removeWhere((_, v) => v == null)) ??
      this;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'metricId': metricId,
    'metricVersion': metricVersion,
    'dimension': dimension,
    'filters': [for (final f in filters) f.toJson()],
    'sort': sort,
    'format': format,
    'layout': layout.toJson(),
    'interaction': interaction,
    'drill': drill,
    'text': ?text,
    if (!style.isDefault) 'style': style.toJson(),
  };

  static BiReportVisual? fromJson(Object? raw) {
    final r = biReportReader(raw);
    if (r == null || !biReportOnly(r, _keys)) return null;
    final id = r.raw('id');
    final type = BiVisualType.fromWire(r.raw('type'));
    final layout = BiVisualLayout.fromJson(r.raw('layout'));
    final filters = biReportFilters(r.raw('filters'));
    final metric = r.raw('metricId');
    final version = r.raw('metricVersion');
    final text = r.raw('text');
    final interaction = r.raw('interaction') ?? 'filter';
    final style = BiVisualStyle.fromJson(r.raw('style'));
    if (style == null) return null;
    if (id is! String || !biReportId.hasMatch(id)) return null;
    if (type == null || layout == null || filters == null) return null;
    if (version is! int || version < 1 || version > 99) return null;
    if (!_bound(type, metric, r.raw('dimension'), r.raw('drill'))) return null;
    if (!_plain(type, text) || !_choices(r, interaction)) return null;
    return BiReportVisual(
      id: id,
      type: type,
      metricId: metric as String?,
      metricVersion: version,
      dimension: r.raw('dimension') as String?,
      filters: filters,
      sort: r.raw('sort') as String?,
      format: r.raw('format') as String?,
      layout: layout,
      interaction: interaction as String,
      drill: r.raw('drill') as String?,
      text: text as String?,
      style: style,
    );
  }

  /// The registered names a visual points at; a text carries no metric,
  /// every other visual needs one. A drill is only ever absent (the
  /// figure's own source) or [noDrill]: any other word would read as "on"
  /// without being a source anyone registered.
  static bool _bound(BiVisualType t, Object? metric, Object? dim, Object? drill) =>
      (t == BiVisualType.text) == (metric == null) &&
      _name(metric) &&
      (dim == null || _reportDimensions.contains(dim)) &&
      (drill == null || drill == noDrill);

  /// Plain content, and only on a text visual.
  static bool _plain(BiVisualType t, Object? text) =>
      (t == BiVisualType.text) == (text != null) &&
      (text == null || (text is String && text.length <= maxText));

  static bool _choices(JsonReader r, Object? interaction) =>
      interactions.contains(interaction) &&
      (r.raw('sort') == null || sorts.contains(r.raw('sort'))) &&
      (r.raw('format') == null || formats.contains(r.raw('format')));

  /// Absent, or a registered name of at most 64 characters.
  static bool _name(Object? v) =>
      v == null || (v is String && v.length <= 64 && _reportName.hasMatch(v));
}
