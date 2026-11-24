// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'counter_till.dart';
import 'embedded_till_values.dart';

/// A refusal is a protocol code; the consuming UI supplies its localized wording.
class EmbeddedTillProfileRefused implements Exception {
  const EmbeddedTillProfileRefused(this.code);
  final String code;
  @override
  String toString() => code;
}

/// The generated default preserves key order and references without enabling sales.
class EmbeddedTillProfile {
  EmbeddedTillProfile._(this._value);

  final Map<String, Object?> _value;

  factory EmbeddedTillProfile.project({
    required String profileId,
    required int revision,
    required String currency,
    required int minorDigits,
    required List<TillKey> keys,
  }) {
    if (keys.length > EmbeddedTillLimits.pages * EmbeddedTillLimits.keysPerPage)
      _refuse('capacity_exceeded');
    final pages = <Map<String, Object?>>[];
    for (
      var offset = 0;
      offset < keys.length || offset == 0;
      offset += EmbeddedTillLimits.keysPerPage
    ) {
      final page = keys.skip(offset).take(EmbeddedTillLimits.keysPerPage);
      pages.add({
        'number': pages.length + 1,
        'keys': [
          for (final key in page)
            {
              'item_id': key.id,
              'label': key.name,
              'unit': key.unit,
              'quantity': '1',
              if (key.grossMinor != null)
                'gross_minor': key.grossMinor.toString(),
            },
        ],
      });
    }
    return EmbeddedTillProfile.fromJson({
      'protocol': {
        'major': EmbeddedTillLimits.major,
        'minor': EmbeddedTillLimits.minor,
      },
      'board_id': EmbeddedTillLimits.boardId,
      'width': EmbeddedTillLimits.width,
      'height': EmbeddedTillLimits.height,
      'profile_id': profileId,
      'revision': revision,
      'mode': 'diagnostic',
      'financial_actions_enabled': false,
      'required_capabilities': ['profile.v1', 'diagnostics'],
      'currency': currency,
      'minor_digits': minorDigits,
      'pages': pages,
    });
  }

  factory EmbeddedTillProfile.fromJson(Object? value) {
    final encoded = utf8.encode(jsonEncode(value));
    if (encoded.length > EmbeddedTillLimits.responseBytes)
      _refuse('payload_too_large');
    final root = _object(value, const {
      'protocol',
      'board_id',
      'width',
      'height',
      'profile_id',
      'revision',
      'mode',
      'financial_actions_enabled',
      'required_capabilities',
      'currency',
      'minor_digits',
      'pages',
    });
    _header(root);
    _pages(root['pages']);
    // Freeze a private JSON-only copy; caller mutations never alter a validated profile.
    return EmbeddedTillProfile._(
      (jsonDecode(utf8.decode(encoded)) as Map).cast<String, Object?>(),
    );
  }

  String encode() => jsonEncode(_value);
  int get pageCount => (_value['pages']! as List).length;
  int get keyCount => (_value['pages']! as List).fold(
    0,
    (sum, page) => sum + ((page as Map)['keys'] as List).length,
  );
}

Never _refuse(String code) => throw EmbeddedTillProfileRefused(code);

Map<String, Object?> _object(Object? value, Set<String> allowed) {
  if (value is! Map ||
      value.keys.any((key) => key is! String || !allowed.contains(key)))
    _refuse('invalid_profile');
  return value.cast<String, Object?>();
}

bool _uuid(Object? value) =>
    value is String &&
    value.length == 36 &&
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
        .hasMatch(value);

bool _text(Object? value, int maximum) =>
    value is String &&
    value.isNotEmpty &&
    utf8.encode(value).length <= maximum &&
    utf8.decode(utf8.encode(value)) == value &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

void _header(Map<String, Object?> root) {
  final protocol = _object(root['protocol'], const {'major', 'minor'});
  if (protocol['major'] != EmbeddedTillLimits.major ||
      protocol['minor'] != EmbeddedTillLimits.minor)
    _refuse('unsupported_protocol');
  if (root['board_id'] != EmbeddedTillLimits.boardId ||
      root['width'] != EmbeddedTillLimits.width ||
      root['height'] != EmbeddedTillLimits.height)
    _refuse('unsupported_board');
  if (root['mode'] != 'diagnostic' ||
      root['financial_actions_enabled'] != false)
    _refuse('financial_action_forbidden');
  final revision = root['revision'];
  if (!_uuid(root['profile_id']) ||
      revision is! num ||
      !revision.isFinite ||
      revision < 1 ||
      revision > EmbeddedTillLimits.revisionMax ||
      revision % 1 != 0)
    _refuse('invalid_profile');
  final currency = root['currency'];
  if (currency is! String ||
      currency.length != 3 ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(currency))
    _refuse('invalid_profile');
  if (!EmbeddedTillLimits.minorDigits.contains(root['minor_digits']))
    _refuse('invalid_money');
  final capabilities = root['required_capabilities'];
  if (capabilities is! List ||
      capabilities.length > EmbeddedTillLimits.capabilities.length ||
      capabilities.toSet().length != capabilities.length ||
      capabilities.any((c) => !EmbeddedTillLimits.capabilities.contains(c)))
    _refuse('unsupported_capability');
}

void _pages(Object? value) {
  if (value is! List) _refuse('invalid_profile');
  if (value.isEmpty || value.length > EmbeddedTillLimits.pages)
    _refuse('capacity_exceeded');
  final seen = <String>{};
  for (var i = 0; i < value.length; i++) {
    final page = _object(value[i], const {'number', 'keys'});
    if (page['number'] != i + 1) _refuse('invalid_profile');
    final keys = page['keys'];
    if (keys is! List) _refuse('invalid_profile');
    if (keys.length > EmbeddedTillLimits.keysPerPage)
      _refuse('capacity_exceeded');
    for (final entry in keys) {
      final key = _object(entry, const {
        'item_id',
        'label',
        'unit',
        'quantity',
        'gross_minor',
      });
      _key(key);
      if (!seen.add(key['item_id']! as String)) _refuse('invalid_profile');
    }
  }
}

void _key(Map<String, Object?> key) {
  if (!_uuid(key['item_id']) ||
      !_text(key['label'], EmbeddedTillLimits.labelBytes) ||
      !_text(key['unit'], EmbeddedTillLimits.unitBytes))
    _refuse('invalid_profile');
  final quantity = key['quantity'];
  if (quantity is! String || embeddedQuantityOf(quantity) == null)
    _refuse('invalid_quantity');
  if (key.containsKey('gross_minor')) {
    final gross = key['gross_minor'];
    final parsed = gross is String ? embeddedMinorOf(gross) : null;
    if (parsed == null || parsed.isNegative) _refuse('invalid_money');
  }
}
