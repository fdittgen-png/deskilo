// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — minimization BEFORE persistence.
//
// A step's payload is a projection onto a finite vocabulary, made at the
// moment of capture. Nothing is gathered first and redacted later: a key
// the action does not declare is dropped, and a value outside the
// field's vocabulary becomes the typed placeholder [withheldValue]. So
// a password, a badge code, a member's name, a message body, an amount,
// a reservation id, a workspace id or a URL cannot reach the store, the
// export, a log line or a support bundle through a payload — there is no
// field that could hold one.
//
// Every value here is a CATEGORY. A date is "today" or "later this
// week", never the day; a resource is "a desk", never which desk; a
// booking is "for another member", never for whom. A field change says
// which field was committed, never its value.

import 'package:meta/meta.dart';

/// The placeholder a value outside its field's vocabulary becomes.
@visibleForTesting
const String withheldValue = 'withheld';

/// One payload field and the only values it can carry.
class SafeField {
  const SafeField(this.key, this.values, {this.soft = false});

  final String key;
  final Set<String> values;

  /// #2142 — a value this build does not know reads as [withheldValue]
  /// instead of refusing the file: the generic labels grow with the app.
  final bool soft;
}

/// A minimized payload: allow-listed keys, vocabulary values only.
class SafePayload {
  const SafePayload._(this.values);

  static const SafePayload empty = SafePayload._(<String, String>{});

  /// Projects [raw] onto [declared]: keys outside it are dropped, values
  /// outside the field's vocabulary in [fields] become [withheldValue].
  /// Never throws.
  factory SafePayload.minimize(
    Set<String> declared,
    Map<String, Object?> raw, {
    required Map<String, SafeField> fields,
  }) {
    if (raw.isEmpty || declared.isEmpty) return empty;
    final out = <String, String>{};
    for (final key in declared) {
      if (!raw.containsKey(key)) continue;
      final field = fields[key];
      if (field == null) continue;
      final value = raw[key];
      out[key] = value is String && field.values.contains(value)
          ? value
          : withheldValue;
    }
    return out.isEmpty ? empty : SafePayload._(Map.unmodifiable(out));
  }

  /// Reads a stored or imported payload strictly: returns null when any
  /// key is undeclared or any value is outside its vocabulary (the
  /// placeholder is allowed). An import cannot smuggle data through it.
  static SafePayload? parse(
    Set<String> declared,
    Object? json, {
    required Map<String, SafeField> fields,
  }) {
    if (json == null) return empty;
    if (json is! Map) return null;
    final out = <String, String>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !declared.contains(key)) return null;
      final field = fields[key];
      if (field == null || value is! String) return null;
      if (value != withheldValue && !field.values.contains(value)) {
        if (!field.soft) return null;
        out[key] = withheldValue;
        continue;
      }
      out[key] = value;
    }
    return out.isEmpty ? empty : SafePayload._(Map.unmodifiable(out));
  }

  final Map<String, String> values;

  bool get isEmpty => values.isEmpty;

  /// Keys in a stable order, so two equal payloads encode alike.
  Map<String, String> toJson() {
    final keys = values.keys.toList()..sort();
    return {for (final k in keys) k: values[k]!};
  }

  @override
  bool operator ==(Object other) =>
      other is SafePayload &&
      other.values.length == values.length &&
      values.entries.every((e) => other.values[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
