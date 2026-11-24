// SPDX-License-Identifier: AGPL-3.0-or-later
// Shared wire cases prove the producer's exact amounts and bounded default projection.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/embedded_till_profile.dart';
import 'package:deskilo/features/money/domain/embedded_till_values.dart';

int _checked = 0;

void _equal(Object? actual, Object? expected, String name) {
  if (actual != expected)
    throw StateError('$name: expected $expected, found $actual');
  _checked++;
}

void main() {
  const directory = 'contracts/embedded_till/v1/fixtures';
  final decimals = jsonDecode(
    File('$directory/decimal_cases.json').readAsStringSync(),
  ) as Map;
  for (final entry in decimals['minor'] as List) {
    _equal(
      embeddedMinorOf(entry['input'] as String)?.toString(),
      entry['expected'],
      'minor ${entry['input']}',
    );
  }
  for (final entry in decimals['quantity'] as List) {
    _equal(
      embeddedQuantityOf(entry['input'] as String)?.toString(),
      entry['expected'],
      'quantity ${entry['input']}',
    );
  }
  for (final entry in decimals['line'] as List) {
    _equal(
      embeddedLineTotal(
        entry['unit_minor'] as String,
        entry['quantity'] as String,
      ),
      entry['expected'],
      'line $entry',
    );
  }
  final cases = jsonDecode(
    File('$directory/profile_cases.json').readAsStringSync(),
  ) as List;
  for (final entry in cases) {
    final value = jsonDecode(
      File('$directory/${entry['file']}').readAsStringSync(),
    );
    _equal(_verdict(value), entry['expected'], 'profile ${entry['file']}');
  }
  _projection(directory);
  _limits();
  stdout.writeln('terminal Dart contract: $_checked producer cases passed');
}

String _verdict(Object? value) {
  try {
    EmbeddedTillProfile.fromJson(value);
    return 'ok';
  } on EmbeddedTillProfileRefused catch (error, stack) {
    if (error.code.isEmpty) Error.throwWithStackTrace(error, stack);
    return error.code;
  }
}

void _projection(String directory) {
  final source = jsonDecode(
    File('$directory/profile_source.json').readAsStringSync(),
  ) as Map;
  final keys = <TillKey>[
    for (final raw in source['keys'] as List)
      TillKey(
        id: raw['id'] as String,
        name: raw['name'] as String,
        unit: raw['unit'] as String,
        grossMinor: int.parse(raw['gross_minor'] as String),
      ),
  ];
  EmbeddedTillProfile project(List<TillKey> values) =>
      EmbeddedTillProfile.project(
        profileId: source['profile_id'] as String,
        revision: source['revision'] as int,
        currency: source['currency'] as String,
        minorDigits: source['minor_digits'] as int,
        keys: values,
      );
  final profile = project(keys);
  _equal(
    profile.encode(),
    File('$directory/profile_valid.json').readAsStringSync().trim(),
    'canonical fixture bytes',
  );
  _equal(profile.keyCount, 2, 'fixture keys');
  _equal(profile.pageCount, 1, 'fixture pages');
  final many = [
    for (var i = 0; i < 96; i++)
      TillKey(
        id: '00000000-0000-0000-0000-${i.toRadixString(16).padLeft(12, '0')}',
        name: 'item $i',
        unit: 'unit',
      ),
  ];
  _equal(project(many).pageCount, 12, 'maximum pages');
  _equal(project(many).keyCount, 96, 'maximum keys');
  _equal(
    project(const []).pageCount,
    1,
    'empty catalogue keeps diagnostic page',
  );
  try {
    project([
      ...many,
      const TillKey(
        id: '00000000-0000-0000-0000-000000999999',
        name: 'extra',
        unit: 'unit',
      ),
    ]);
    throw StateError('oversized projection accepted');
  } on EmbeddedTillProfileRefused catch (error, stack) {
    if (error.code != 'capacity_exceeded')
      Error.throwWithStackTrace(error, stack);
    _checked++;
  }
  final data = jsonDecode(profile.encode()) as Map;
  final frozen = EmbeddedTillProfile.fromJson(data);
  for (final surrogate in ['\ud800', '\udfff']) {
    final invalid = jsonDecode(profile.encode()) as Map;
    ((invalid['pages'] as List).first['keys'] as List).first['label'] =
        surrogate;
    _equal(_verdict(invalid), 'invalid_profile', 'unpaired UTF-16 surrogate');
  }
  data['financial_actions_enabled'] = true;
  _equal(
    frozen.encode(),
    profile.encode(),
    'caller mutation cannot enable actions',
  );
}

void _limits() {
  final value = jsonDecode(
    File('contracts/embedded_till/v1/limits.json').readAsStringSync(),
  ) as Map;
  final actual = {
    'protocol_major': EmbeddedTillLimits.major,
    'protocol_minor': EmbeddedTillLimits.minor,
    'board_id': EmbeddedTillLimits.boardId,
    'width': EmbeddedTillLimits.width,
    'height': EmbeddedTillLimits.height,
    'request_bytes': EmbeddedTillLimits.requestBytes,
    'response_bytes': EmbeddedTillLimits.responseBytes,
    'keys_per_page': EmbeddedTillLimits.keysPerPage,
    'pages': EmbeddedTillLimits.pages,
    'label_bytes': EmbeddedTillLimits.labelBytes,
    'unit_bytes': EmbeddedTillLimits.unitBytes,
    'depth': EmbeddedTillLimits.depth,
  };
  for (final entry in actual.entries)
    _equal(entry.value, value[entry.key], 'limit ${entry.key}');
}
