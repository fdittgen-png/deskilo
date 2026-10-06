// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The values of a step — what a person entered or chose — kept in a typed
// channel of their own, apart from the finite-vocabulary payload.
//
// A recording is private by construction: its payload says WHICH field was
// committed and never its value. A recording started with "capture values"
// switched on (the person's explicit choice, per recording) also keeps what
// was entered, so a file attached to an issue holds everything needed to
// reproduce it. This file is the only place a value can enter a recording:
//   * every value is typed (text, number, flag) and bounded;
//   * secrets, payment identifiers and personal contact data are NEVER
//     kept, with or without the switch: the field is recorded as redacted
//     with only the length of what was typed;
//   * the validator refuses anything else, so a file cannot carry a value
//     the recorder would not have kept.

/// One recorded value.
sealed class RecordedValue {
  const RecordedValue();

  /// The JSON form: a bool, a number, a string, or `{redacted, length}`.
  Object toJson();

  /// Reads one value, or null when it is not one the recorder keeps.
  static RecordedValue? parse(Object? raw) {
    if (raw is bool) return FlagValue(raw);
    if (raw is num) return raw.isFinite ? NumberValue(raw) : null;
    if (raw is String) return TextValue.tryParse(raw);
    if (raw is Map &&
        raw.length == 2 &&
        raw['redacted'] == true &&
        raw['length'] is int &&
        (raw['length'] as int) >= 0 &&
        (raw['length'] as int) <= StepValues.maxLength * 100) {
      return RedactedValue(raw['length'] as int);
    }
    return null;
  }
}

/// A typed text: bounded, no control characters but newline and tab.
final class TextValue extends RecordedValue {
  const TextValue._(this.text);

  final String text;

  /// [text] as it is kept: control characters dropped, cut at the bound.
  factory TextValue(String text) {
    final clean = text.replaceAll(_control, '');
    return TextValue._(
      clean.length > StepValues.maxLength
          ? clean.substring(0, StepValues.maxLength)
          : clean,
    );
  }

  static TextValue? tryParse(String raw) =>
      raw.length > StepValues.maxLength || _control.hasMatch(raw)
          ? null
          : TextValue._(raw);

  @override
  Object toJson() => text;

  @override
  bool operator ==(Object other) => other is TextValue && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

final class NumberValue extends RecordedValue {
  const NumberValue(this.number);

  final num number;

  @override
  Object toJson() => number;

  @override
  bool operator ==(Object other) =>
      other is NumberValue && other.number == number;

  @override
  int get hashCode => number.hashCode;
}

final class FlagValue extends RecordedValue {
  const FlagValue(this.on);

  final bool on;

  @override
  Object toJson() => on;

  @override
  bool operator ==(Object other) => other is FlagValue && other.on == on;

  @override
  int get hashCode => on.hashCode;
}

/// Something was entered here, and the recorder does not keep it: only how
/// long it was.
final class RedactedValue extends RecordedValue {
  const RedactedValue(this.length);

  final int length;

  @override
  Object toJson() => {'redacted': true, 'length': length};

  @override
  bool operator ==(Object other) =>
      other is RedactedValue && other.length == length;

  @override
  int get hashCode => length.hashCode ^ 0x5eed;
}

final RegExp _control = RegExp(r'[\u0000-\u0008\u000B-\u001F\u007F]');
final RegExp _keyPattern = RegExp(r'^[a-z][a-z0-9_.-]{0,39}$');

/// The values one step carries, by name.
class StepValues {
  const StepValues._(this.entries);

  const StepValues.empty() : entries = const {};

  /// The longest text kept; longer input is cut.
  static const int maxLength = 240;

  /// The most values one step may carry.
  static const int maxEntries = 16;

  final Map<String, RecordedValue> entries;

  static const StepValues none = StepValues.empty();

  bool get isEmpty => entries.isEmpty;

  /// Builds values from [raw], dropping a name that is not well formed.
  factory StepValues.of(Map<String, RecordedValue> raw) {
    final kept = <String, RecordedValue>{};
    for (final e in raw.entries) {
      if (!_keyPattern.hasMatch(e.key)) continue;
      if (kept.length >= maxEntries) break;
      kept[e.key] = e.value;
    }
    return kept.isEmpty ? none : StepValues._(Map.unmodifiable(kept));
  }

  /// Reads the JSON object of a file, or null when anything in it is not a
  /// value the recorder keeps — a file never carries more than the recorder
  /// would have kept.
  static StepValues? parse(Object? raw) {
    if (raw == null) return none;
    if (raw is! Map || raw.isEmpty || raw.length > maxEntries) return null;
    final out = <String, RecordedValue>{};
    for (final e in raw.entries) {
      final key = e.key;
      if (key is! String || !_keyPattern.hasMatch(key)) return null;
      final value = RecordedValue.parse(e.value);
      if (value == null) return null;
      out[key] = value;
    }
    return StepValues._(Map.unmodifiable(out));
  }

  /// The canonical JSON object: keys sorted.
  Map<String, Object> toJson() => {
        for (final k in (entries.keys.toList()..sort())) k: entries[k]!.toJson(),
      };

  @override
  bool operator ==(Object other) {
    if (other is! StepValues || other.entries.length != entries.length) {
      return false;
    }
    for (final e in entries.entries) {
      if (other.entries[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        [for (final k in (entries.keys.toList()..sort())) Object.hash(k, entries[k])],
      );
}

/// A value as a short line of text. [redacted], [on] and [off] are the words
/// for the cases that carry no text of their own.
String valueText(
  RecordedValue v, {
  required String Function(int length) redacted,
  required String on,
  required String off,
}) =>
    switch (v) {
      TextValue(:final text) => text,
      NumberValue(:final number) => number.toString(),
      FlagValue(on: final isOn) => isOn ? on : off,
      RedactedValue(:final length) => redacted(length),
    };

/// What a text field's value becomes in a recording.
///
/// A field whose name, label or autofill hint says it holds a secret, a
/// payment identifier or personal contact data — or that hides what is typed
/// — is redacted whatever the switch says. Anything else is kept: a number
/// as a number, the rest as the text typed.
RecordedValue valueOfField(
  String text, {
  bool obscure = false,
  Iterable<String> hints = const [],
  bool numeric = false,
  String? key,
  String? label,
}) {
  if (obscure || _sensitive(hints, key, label)) {
    return RedactedValue(text.length);
  }
  if (numeric) {
    final parsed = num.tryParse(text.trim().replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) return NumberValue(parsed);
  }
  return TextValue(text);
}

bool _sensitive(Iterable<String> hints, String? key, String? label) {
  final probe = [...hints, key ?? '', label ?? ''].join(' ');
  return _sensitiveWords.hasMatch(probe);
}

/// Words that mark a field as one never to keep: credentials, payment
/// identifiers, tax and national identifiers, and personal contact data.
final RegExp _sensitiveWords = RegExp(
  r'pass(word|wort|code|phrase)?|pwd|\bpin\b|otp|one.?time|2fa|totp|token|'
  r'secret|api.?key|credential|iban|\bbic\b|swift|card.?(number|no)|cvc|cvv|'
  r'creditcard|e-?mail|\bmail\b|phone|telephone|\btel\b|mobile|handy|fax|'
  r'address|adresse|street|strasse|straße|postal|zip|\bplz\b|birth|geburt|'
  r'\bssn\b|siren|siret|vat.?(id|number)|\btva\b|ust.?id|tax.?id|username|'
  r'new-?password|current-?password|given.?name|family.?name|first.?name|'
  r'last.?name|surname|vorname|nachname',
  caseSensitive: false,
);
