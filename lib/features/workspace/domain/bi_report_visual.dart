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

/// A registered name: a metric, dimension or drill target.
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
    if (d is! String || !_reportName.hasMatch(d) || d.length > 64) return null;
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

  BiVisualLayout copyWith({int? order}) =>
      BiVisualLayout(order: order ?? this.order, span: span, height: height);

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
  });

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

  /// A registered drill target, or null.
  final String? drill;

  /// Plain content of a text visual, shown escaped.
  final String? text;

  static const maxText = 500;
  static const sorts = {'natural', 'value_desc', 'value_asc'};
  static const formats = {'auto', 'number', 'percent', 'currency'};
  static const interactions = {'filter', 'none'};
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
  };

  BiReportVisual copyWith({BiVisualLayout? layout}) => BiReportVisual(
    id: id,
    type: type,
    metricId: metricId,
    metricVersion: metricVersion,
    dimension: dimension,
    filters: filters,
    sort: sort,
    format: format,
    layout: layout ?? this.layout,
    interaction: interaction,
    drill: drill,
    text: text,
  );

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
    );
  }

  /// The registered names a visual points at; a text carries no metric,
  /// every other visual needs one.
  static bool _bound(BiVisualType t, Object? metric, Object? dim, Object? drill) =>
      (t == BiVisualType.text) == (metric == null) &&
      _name(metric) &&
      _name(dim) &&
      _name(drill);

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
