// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1847 — the one reader of public network records. It keeps only the
// fields the generated contract lists (so an additive field from a newer
// server is ignored and a private field that leaks never reaches a
// screen), refuses a record whose required fields, required states or
// must-understand terms this version cannot interpret, and refuses a
// management input key the contract does not list instead of dropping it.
import 'public_network_operations.dart';
import 'public_network_spec.dart';

/// A record or an input this version of the contract cannot honour.
class PublicContractRefusal implements Exception {
  const PublicContractRefusal(this.schema, this.field, this.reason);
  final String schema, field, reason;
  @override
  String toString() => 'PublicContractRefusal($schema.$field: $reason)';
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _offset = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
final _currency = RegExp(r'^[A-Z]{3}$');

PublicSchema _schema(String name) =>
    publicNetworkSchemas[name] ??
    (throw ArgumentError.value(name, 'schema', 'not in the contract'));

/// The allow-listed projection of [raw] under [schemaName].
///
/// Throws [PublicContractRefusal] when the record cannot be honoured.
Map<String, Object?> decodePublicRecord(String schemaName, Object? raw) {
  final schema = _schema(schemaName);
  if (raw is! Map) {
    throw PublicContractRefusal(schemaName, '', 'not an object');
  }
  final mu = schema.mustUnderstand;
  if (mu != null && raw[mu] != null) {
    final terms = raw[mu];
    if (terms is! List || terms.any((t) => t is! String)) {
      throw PublicContractRefusal(schemaName, mu, 'malformed term list');
    }
    for (final term in terms.cast<String>()) {
      if (!schema.fields.containsKey(term)) {
        throw PublicContractRefusal(schemaName, term, 'unknown required term');
      }
    }
  }
  final out = <String, Object?>{};
  for (final entry in schema.fields.entries) {
    final name = entry.key;
    final field = entry.value;
    final Object? value = raw[name];
    if (value == null) {
      if (field.required) {
        throw PublicContractRefusal(schemaName, name, 'missing');
      }
      continue;
    }
    final Object? kept;
    try {
      kept = _decodeValue(schemaName, name, field, value);
    } on PublicContractRefusal {
      if (field.required) rethrow;
      continue;
    }
    if (kept != null) out[name] = kept;
  }
  return out;
}

Object? _decodeValue(
  String schema,
  String name,
  PublicField field,
  Object value,
) {
  PublicContractRefusal refuse(String reason) =>
      PublicContractRefusal(schema, name, reason);
  String text() {
    if (value is! String) throw refuse('not a string');
    if (field.maxLength != null && value.length > field.maxLength!) {
      throw refuse('too long');
    }
    return value;
  }

  switch (field.type) {
    case PublicFieldType.uuid:
      final v = text();
      if (!_uuid.hasMatch(v)) throw refuse('not a uuid');
      return v;
    case PublicFieldType.datetime:
      final v = text();
      if (!_offset.hasMatch(v) || DateTime.tryParse(v) == null) {
        throw refuse('not an instant with an offset');
      }
      return v;
    case PublicFieldType.text:
      return text();
    case PublicFieldType.boolean:
      if (value is! bool) throw refuse('not a boolean');
      return value;
    case PublicFieldType.enum_:
      final v = text();
      if (!field.values.contains(v)) throw refuse('unknown state $v');
      return v;
    case PublicFieldType.currency:
      final v = text();
      if (!_currency.hasMatch(v)) throw refuse('not an ISO 4217 code');
      return v;
    case PublicFieldType.decimal:
      final v = text();
      final n = num.tryParse(v);
      if (n == null ||
          !n.isFinite ||
          (field.min != null && n < field.min!) ||
          (field.max != null && n > field.max!)) {
        throw refuse('not a decimal in range');
      }
      return v;
    case PublicFieldType.httpsUrl:
      final v = text();
      final uri = Uri.tryParse(v);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw refuse('not an https link');
      }
      return v;
    case PublicFieldType.httpsOrigin:
      final v = text();
      final uri = Uri.tryParse(v);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.origin != v) {
        throw refuse('not an https origin');
      }
      return v;
    case PublicFieldType.object:
      return decodePublicRecord(field.schema!, value);
    case PublicFieldType.array:
      if (value is! List) throw refuse('not a list');
      final items = <Map<String, Object?>>[];
      for (final item in value) {
        if (field.maxItems != null && items.length >= field.maxItems!) break;
        try {
          items.add(decodePublicRecord(field.schema!, item));
        } on PublicContractRefusal {
          // One malformed element is dropped; the list stays usable.
        }
      }
      return items;
  }
}

/// Refuses an input object for [schemaName] that carries a key the
/// contract does not list, a non-string value, an over-long value or a
/// missing/unknown required enum — before anything is sent.
Map<String, String> encodePublicInput(
  String schemaName,
  Map<String, String> input,
) {
  final schema = _schema(schemaName);
  for (final key in input.keys) {
    if (!schema.fields.containsKey(key)) {
      throw PublicContractRefusal(schemaName, key, 'unknown input');
    }
  }
  for (final entry in schema.fields.entries) {
    final value = input[entry.key];
    final field = entry.value;
    if (value == null) {
      if (field.required) {
        throw PublicContractRefusal(schemaName, entry.key, 'missing');
      }
      continue;
    }
    if (field.maxLength != null && value.length > field.maxLength!) {
      throw PublicContractRefusal(schemaName, entry.key, 'too long');
    }
    if (field.type == PublicFieldType.enum_ && !field.values.contains(value)) {
      throw PublicContractRefusal(schemaName, entry.key, 'unknown state');
    }
  }
  return Map.unmodifiable(input);
}

/// The operation [id], for a caller holding only its stable identifier.
/// Code uses the generated `PublicNetworkOperations` constants instead, so
/// a renamed or removed operation is a compile error at every caller.
PublicOperationSpec publicOperation(String id) =>
    publicNetworkOperations[id] ??
    (throw ArgumentError.value(id, 'operation', 'not in the contract'));
