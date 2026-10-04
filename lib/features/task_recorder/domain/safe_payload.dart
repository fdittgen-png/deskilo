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

import 'ui_vocabulary.g.dart';

/// The placeholder a value outside its field's vocabulary becomes.
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

/// The whole field list. Adding a field is a reviewed change to this
/// file; there is no other way for a value to reach a recording.
const Map<String, SafeField> safeFields = {
  'date_relation': SafeField('date_relation', {
    'today',
    'tomorrow',
    'later_this_week',
    'later',
    'past',
  }),
  'period': SafeField('period', {
    'full_day',
    'morning',
    'afternoon',
    'hours',
    'custom',
  }),
  'view_mode': SafeField('view_mode', {
    'plan',
    'list',
    'day',
    'week',
    'month',
    'agenda',
    'timeline',
    'range',
  }),
  'resource_kind': SafeField('resource_kind', {'desk', 'room', 'other'}),
  'for_whom': SafeField('for_whom', {'self', 'other_member'}),
  'repeat': SafeField('repeat', {'once', 'series'}),
  'check_in': SafeField('check_in', {'yes', 'no'}),
  'switch_to': SafeField('switch_to', {'on', 'off'}),
  'series_result': SafeField('series_result', {
    'all_booked',
    'partially_booked',
  }),
  // #2142 — a control's or a screen's label: one of the app's own
  // messages (by key), never text somebody typed.
  'label': SafeField('label', uiLabelKeys, soft: true),
  // #1881 B — the calendar: which way the dates moved, whose calendar,
  // which kind of entry was opened; and a decision's answer.
  'direction': SafeField('direction', {'previous', 'next', 'today'}),
  'calendar_of': SafeField('calendar_of', {
    'mine',
    'someone_else',
    'everyone',
  }),
  'item_kind': SafeField('item_kind', {
    'conversation',
    'alert',
    'decision',
    'payment',
    'invoice',
  }),
  'decision': SafeField('decision', {'accept', 'decline'}),
  // #1884 B — the built-in role a permission was switched for, and what
  // happened to a role the space defines.
  'role_kind': SafeField('role_kind', {
    'owner',
    'co_owner',
    'admin',
    'member',
  }),
  'role_change': SafeField('role_change', {'created', 'edited', 'renamed'}),
  'refusal': SafeField('refusal', {
    'conflict',
    'policy',
    'quota',
    'permission',
    'closed',
    'offline',
    'other',
  }),
};

/// A minimized payload: allow-listed keys, vocabulary values only.
class SafePayload {
  const SafePayload._(this.values);

  static const SafePayload empty = SafePayload._(<String, String>{});

  /// Projects [raw] onto [declared]: keys outside it are dropped, values
  /// outside the field's vocabulary become [withheldValue]. Never throws.
  factory SafePayload.minimize(Set<String> declared, Map<String, Object?> raw) {
    if (raw.isEmpty || declared.isEmpty) return empty;
    final out = <String, String>{};
    for (final key in declared) {
      if (!raw.containsKey(key)) continue;
      final field = safeFields[key];
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
  static SafePayload? parse(Set<String> declared, Object? json) {
    if (json == null) return empty;
    if (json is! Map) return null;
    final out = <String, String>{};
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !declared.contains(key)) return null;
      final field = safeFields[key];
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
