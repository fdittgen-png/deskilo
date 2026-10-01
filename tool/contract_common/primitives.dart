// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the rendering primitives the MCP contract (#1609) and the public
// network contract share: one JSON Schema per typed field, one JSON layout
// and one identifier casing, so two generated contracts cannot disagree on
// what a `uuid` or an offset-bearing `datetime` is.
import 'dart:convert';

/// The JSON Schema of one typed field.
Map<String, Object?> fieldSchema(Map<String, dynamic> f) => switch (f['type']) {
  'uuid' => {'type': 'string', 'format': 'uuid'},
  'datetime' => {
    'type': 'string',
    'format': 'date-time',
    'pattern': r'(Z|[+-]\d{2}:\d{2})$',
  },
  'month' => {'type': 'string', 'pattern': r'^\d{4}-(0[1-9]|1[0-2])$'},
  'integer' => {
    'type': 'integer',
    if (f['min'] != null) 'minimum': f['min'],
    if (f['max'] != null) 'maximum': f['max'],
  },
  'boolean' => {'type': 'boolean'},
  'text' => {'type': 'string', 'maxLength': f['maxLength'] ?? 500},
  'enum' => {'type': 'string', 'enum': f['values']},
  final t => throw FormatException('unknown field type $t'),
};

/// Two-space indented JSON with a trailing newline: every committed
/// rendering uses this layout, so a drift test compares bytes.
String prettyJson(Object? o) =>
    '${const JsonEncoder.withIndent('  ').convert(o)}\n';

/// `snake_case` (or `dotted.snake_case`) to `lowerCamelCase`.
String camelCase(String snake) {
  final parts = snake.split(RegExp('[_.]'));
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}
