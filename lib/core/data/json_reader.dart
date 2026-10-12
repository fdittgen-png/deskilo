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
///
/// **The policy, decided once (#2387):**
/// - A row refuses a shape it does not expect: a missing required field,
///   or ANY field of the wrong type (also an optional one), is a
///   [JsonShapeException], never a silent default.
/// - An enum value read off the wire goes through the enum's `fromWire`;
///   an unknown value is refused where a wrong reading would be unsafe
///   (`TaxTreatment`, `BookAuthority`) and traced with a safe fallback
///   where a newer server may widen the set (`enumOr`, #1148) — the
///   enum's own `fromWire` says which.
/// - The **fail-closed** reads ([textOrAbsent], [isTrue], [intOrAbsent],
///   [listOrAbsent], [objectOrAbsent]) are for the few decoders whose
///   answer guards a door — consent, identity, MCP policy, invitations:
///   there a malformed field reads as absent, which those decoders map to
///   the safe state (unavailable, not eligible, unknown). Never for a row.
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

  /// [raw] as a reader, or an empty one when it is not an object: for the
  /// fail-closed decoders, which then read every field as absent.
  factory JsonReader.orEmpty(Object? raw, {String context = 'row'}) =>
      JsonReader.of(raw is Map ? raw : const <String, Object?>{}, context: context);

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

  /// A required decimal (a rate).
  double number(String key) {
    final value = json[key];
    return value is num ? value.toDouble() : _shape(key, 'num');
  }

  /// A required number, integer or decimal as it arrived (a weight).
  num numeric(String key) {
    final value = json[key];
    return value is num ? value : _shape(key, 'num');
  }

  /// A nullable number, integer or decimal as it arrived.
  num? numOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    return value is num ? value : _shape(key, 'num?');
  }

  /// A nullable decimal (an average, a ratio).
  double? doubleOrNull(String key) {
    final value = json[key];
    if (value == null) return null;
    return value is num ? value.toDouble() : _shape(key, 'double?');
  }

  /// A boolean the wire may omit: [fallback] then.
  // ignore: avoid_positional_boolean_parameters — #2389, an existing API; named when it next changes
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

  /// A JSON array the wire may omit: empty then; its elements unread.
  List<Object?> list(String key) {
    final value = json[key];
    if (value == null) return const [];
    return value is List ? value : _shape(key, 'List?');
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

  // Fail-closed reads — see the library comment: for the decoders whose
  // safe reading of a malformed field is "absent". Never for a row.

  /// The text at [key] if it is a string; absent (null) otherwise.
  String? textOrAbsent(String key) {
    final value = json[key];
    return value is String ? value : null;
  }

  /// True only when [key] holds `true`; anything else reads as false.
  bool isTrue(String key) => json[key] == true;

  /// The integer at [key] if it is one; absent (null) otherwise.
  int? intOrAbsent(String key) {
    final value = json[key];
    return value is int ? value : null;
  }

  /// The array at [key] if it is one; empty otherwise.
  List<Object?> listOrAbsent(String key) {
    final value = json[key];
    return value is List ? value : const [];
  }

  /// The object at [key] if it is one, as a reader; empty otherwise.
  JsonReader objectOrAbsent(String key) {
    final value = json[key];
    return JsonReader(
      value is Map ? Map<String, Object?>.from(value) : const {},
      context: '$context.$key',
    );
  }
}

String _typeOf(Object? value) =>
    value == null ? 'null' : value.runtimeType.toString();
