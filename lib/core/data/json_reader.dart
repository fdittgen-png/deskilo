// SPDX-License-Identifier: AGPL-3.0-or-later

/// One typed decoder for the rows the server sends (#2387).
///
/// The data layer decoded JSON by hand: `json['x'] as String`,
/// `(json['n'] as num?)?.toInt() ?? 0`, `DateTime.parse(json['at'] as
/// String)`, once per field in every `fromJson`. A renamed column or a
/// nullable that became non-null was caught by nothing until a screen
/// threw `type 'Null' is not a subtype of type 'String'`, which names
/// neither the row nor the field.
///
/// A [JsonReader] reads one row. A required field that is missing or of
/// the wrong type throws a [JsonShapeException] naming the [context]
/// (the RPC or table the row came from), the key, the expected type and
/// what arrived — the line a trace needs. The `…Or` readers are for the
/// fields the wire may legitimately omit, and say so at the call site.
library;

/// A row did not have the shape its decoder expects.
class JsonShapeException implements Exception {
  const JsonShapeException(this.context, this.key, this.expected, this.actual);

  /// Where the row came from: the RPC or table name.
  final String context;
  final String key;

  /// The Dart type the decoder needed, e.g. `String`.
  final String expected;

  /// What arrived: `null` (missing) or the runtime type.
  final String actual;

  @override
  String toString() =>
      'JsonShapeException: $context.$key expected $expected, got $actual';
}

/// Typed reads over one decoded JSON object.
class JsonReader {
  JsonReader(this.json, {this.context = 'row'});

  /// [raw] as a reader; a non-object is a shape error of the whole row.
  factory JsonReader.of(Object? raw, {String context = 'row'}) {
    if (raw is Map<String, Object?>) return JsonReader(raw, context: context);
    if (raw is Map) {
      return JsonReader(Map<String, Object?>.from(raw), context: context);
    }
    throw JsonShapeException(context, '', 'object', _typeOf(raw));
  }

  final Map<String, Object?> json;

  /// The RPC or table the row came from, for the error message.
  final String context;

  Never _shape(String key, String expected) =>
      throw JsonShapeException(context, key, expected, _typeOf(json[key]));

  /// A required text field.
  String string(String key) {
    final value = json[key];
    return value is String ? value : _shape(key, 'String');
  }

  /// A text field the wire may omit or send as null: [fallback] then.
  /// A value of another type is still a shape error, not a fallback.
  String stringOr(String key, [String fallback = '']) =>
      stringOrNull(key) ?? fallback;

  /// A nullable text field.
  String? stringOrNull(String key) {
    final value = json[key];
    if (value == null || value is String) return value as String?;
    return _shape(key, 'String?');
  }

  /// A required integer (Postgres numbers arrive as int or double).
  int integer(String key) {
    final value = json[key];
    return value is num ? value.toInt() : _shape(key, 'int');
  }

  /// A nullable integer (Postgres numbers arrive as int or double).
  int? intOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    return value is num ? value.toInt() : _shape(key, 'int?');
  }

  /// A nullable decimal (an average, a ratio).
  double? doubleOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    return value is num ? value.toDouble() : _shape(key, 'double?');
  }

  /// A boolean the wire may omit: [fallback] then.
  bool boolOr(String key, bool fallback) {
    final value = json[key];
    if (value == null) return fallback;
    return value is bool ? value : _shape(key, 'bool?');
  }

  /// A required ISO-8601 timestamp, as parsed (callers convert).
  DateTime dateTime(String key) {
    final value = json[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed ?? _shape(key, 'ISO-8601 String');
  }

  /// A nullable ISO-8601 timestamp, as parsed.
  DateTime? dateTimeOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed ?? _shape(key, 'ISO-8601 String?');
  }

  /// A nested object the wire may omit or send as null: null then. Its
  /// reader's context is `<context>.<key>`.
  JsonReader? objectOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is Map) {
      return JsonReader(
        Map<String, Object?>.from(value),
        context: '$context.$key',
      );
    }
    return _shape(key, 'object?');
  }

  /// A JSON object field the wire may omit: empty then.
  Map<String, Object?> objectOrEmpty(String key) {
    final value = json[key];
    if (value == null) return const {};
    if (value is Map) return Map<String, Object?>.from(value);
    return _shape(key, 'object?');
  }

  /// A JSON array of strings the wire may omit: empty then.
  List<String> strings(String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is List && value.every((item) => item is String)) {
      return List<String>.from(value);
    }
    return _shape(key, 'List<String>?');
  }

  /// A JSON array of objects the wire may omit: each element decoded
  /// with [decode] through its own reader (same [context], so an error
  /// inside an element still names the RPC).
  List<T> objects<T>(String key, T Function(JsonReader row) decode) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List) return _shape(key, 'List?');
    return [
      for (final item in value) decode(JsonReader.of(item, context: context)),
    ];
  }
}

String _typeOf(Object? value) =>
    value == null ? 'null' : value.runtimeType.toString();
