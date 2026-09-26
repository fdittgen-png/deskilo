// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1609 — the shapes the generated operation catalogue
// (`mcp_operations.dart`) is written in, and the one input validator every
// MCP adapter uses. The catalogue grants nothing: SQL decides who may do
// what; this refuses malformed or identity-bearing input before it gets
// that far.

enum McpAuthority { self, member, permission }

enum McpScope { discovery, own, workspace }

enum McpMutation { read, write, request, decision }

enum McpFieldType { uuid, datetime, month, integer, boolean, text, enum_ }

class McpField {
  const McpField(
    this.type, {
    this.required = false,
    this.min,
    this.max,
    this.maxLength,
    this.values = const [],
    this.param,
  });

  final McpFieldType type;
  final bool required;
  final int? min, max, maxLength;
  final List<String> values;

  /// The RPC parameter this field fills, when the operation has one.
  final String? param;
}

class McpOperationSpec {
  const McpOperationSpec({
    required this.id,
    required this.rpc,
    required this.handler,
    required this.dispatch,
    required this.authority,
    required this.permission,
    required this.features,
    required this.scope,
    required this.mutation,
    required this.idempotent,
    required this.nativeConfirmation,
    required this.fields,
    required this.output,
  });

  final String id;

  /// The existing Supabase RPC this operation binds to; null while the
  /// read has no RPC of its own.
  final String? rpc;

  /// Whether an MCP handler exists. Only these may be advertised.
  final bool handler;

  /// #1612 — whether `mcp_execute_v1` implements it. Only these may be
  /// named in a workspace policy.
  final bool dispatch;
  final McpAuthority authority;
  final String? permission;
  final List<String> features;
  final McpScope scope;
  final McpMutation mutation;
  final bool idempotent;
  final bool nativeConfirmation;
  final Map<String, McpField> fields;
  final List<String> output;
}

final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false);
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
