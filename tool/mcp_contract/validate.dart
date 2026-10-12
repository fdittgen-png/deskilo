// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 / #2394 — the contract's input rules as Dart: the reference the
// server adapter's validator (supabase/functions/_shared/mcp_validate.ts)
// mirrors, field code for field code. It lives beside the generator: the
// app never runs it (the server validates every call).
import 'package:deskilo/core/mcp/mcp_spec.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final _month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
final _offset = RegExp(r'(Z|[+-]\d{2}:\d{2})$');

/// Field errors for [input] against [spec], by field name; empty = valid.
///
/// Unknown fields are refused (a typo is not silently ignored), identity
/// and authority fields are refused by name whatever the operation, a
/// timestamp without an offset is refused (the server owns the zone).
Map<String, String> validateMcpInput(
  McpOperationSpec spec,
  Map<String, Object?> input, {
  Set<String> forbidden = const {},
}) {
  final errors = <String, String>{};
  for (final key in input.keys) {
    if (forbidden.contains(key)) {
      errors[key] = 'forbidden';
    } else if (!spec.fields.containsKey(key)) {
      errors[key] = 'unknown_field';
    }
  }
  for (final entry in spec.fields.entries) {
    final name = entry.key;
    final field = entry.value;
    if (!input.containsKey(name) || input[name] == null) {
      if (field.required) errors[name] = 'required';
      continue;
    }
    final error = _check(field, input[name]);
    if (error != null) errors[name] = error;
  }
  return errors;
}

String? _check(McpField f, Object? v) {
  switch (f.type) {
    case McpFieldType.uuid:
      return v is String && _uuid.hasMatch(v) ? null : 'invalid_uuid';
    case McpFieldType.month:
      return v is String && _month.hasMatch(v) ? null : 'invalid_month';
    case McpFieldType.datetime:
      if (v is! String || !_offset.hasMatch(v)) return 'invalid_datetime';
      return DateTime.tryParse(v) == null ? 'invalid_datetime' : null;
    case McpFieldType.integer:
      if (v is! int) return 'invalid_integer';
      if (f.min != null && v < f.min!) return 'too_small';
      if (f.max != null && v > f.max!) return 'too_large';
      return null;
    case McpFieldType.boolean:
      return v is bool ? null : 'invalid_boolean';
    case McpFieldType.text:
      if (v is! String) return 'invalid_text';
      return v.length > (f.maxLength ?? 500) ? 'too_long' : null;
    case McpFieldType.enum_:
      return v is String && f.values.contains(v) ? null : 'invalid_value';
  }
}
